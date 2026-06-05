#!/usr/bin/env bash
# score-agents.sh - Grade AGENTS.md files with a reproducible quality score.
#
# Aggregates the --json output of the four verifier scripts into a per-file
# letter grade (A-F) on a 0-100 scale, ranked worst-first so you know where to
# spend effort. Reproducible: re-running on an unchanged tree yields the same
# grade (no model call, CI-friendly). One caveat - the Currency axis can shift
# within a day for a file whose "Last updated" date is today, because
# check-freshness.sh uses git's bare-date --since.
#
# Five script-measured axes (max points):
#   Structure 25 | Currency 20 | Content 20 | Commands 15 (root only) | Conciseness 20
# A file's percentage = earned / (sum of applicable axis maxima) * 100.
# Scoped files have no Commands axis; their maxima sum to 85 and normalise to 100.
#
# Grades: A >=90  B >=75  C >=50  D >=30  F <30
#
# A separate, QUALITATIVE LLM overlay (Architecture / Actionability /
# Non-obvious-patterns) is NOT part of this number - it varies run to run. See
# references/quality-rubric.md for how an agent layers that review on top.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROJECT_DIR=""
JSON=false
REVIEW_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --json)
            JSON=true
            shift
            ;;
        --review)
            REVIEW_FILE="${2:-}"
            shift 2
            ;;
        --review=*)
            REVIEW_FILE="${1#*=}"
            shift
            ;;
        --help|-h)
            cat <<EOF
Usage: score-agents.sh [PROJECT_DIR] [OPTIONS]

Grade AGENTS.md files with a reproducible 0-100 quality score (worst-first).

Options:
  --json            Emit the machine-readable scoring document on stdout
  --review FILE     Add a secondary, NON-reproducible "with review" grade from a
                    JSON of agent-judged LLM-axis ratings (see quality-rubric.md):
                    { "PATH": {"architecture":"strong|adequate|weak",
                               "actionability":"...","non_obvious":"..."}, ... }
  --help, -h        Show this help message

Axes: Structure 25 | Currency 20 | Content 20 | Commands 15 (root) | Conciseness 20
Grades: A >=90  B >=75  C >=50  D >=30  F <30

The deterministic score never changes on an unchanged tree. The --review overlay
(Architecture, Actionability, Non-obvious patterns) varies and is shown separately.
EOF
            exit 0
            ;;
        *)
            PROJECT_DIR="$1"
            shift
            ;;
    esac
done

PROJECT_DIR="${PROJECT_DIR:-.}"

if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required" >&2
    exit 2
fi

# Optional LLM-axis ratings for the secondary "with review" grade.
REVIEW_JSON='{}'
if [[ -n "$REVIEW_FILE" ]]; then
    if [[ -f "$REVIEW_FILE" ]] && jq -e . "$REVIEW_FILE" >/dev/null 2>&1; then
        REVIEW_JSON=$(cat "$REVIEW_FILE")
    else
        echo "Error: --review file missing or not valid JSON: $REVIEW_FILE" >&2
        exit 2
    fi
fi

# Run a verifier in --json mode; tolerate its non-zero "issues found" exit and
# its human stderr. Echo '{}' if it produced nothing parseable so jq stays happy.
run_json() {
    local script="$1"
    shift
    local out
    out=$(bash "$SCRIPT_DIR/$script" "$PROJECT_DIR" --json "$@" 2>/dev/null || true)
    if [[ -n "$out" ]] && printf '%s' "$out" | jq -e . >/dev/null 2>&1; then
        printf '%s' "$out"
    else
        echo '{}'
    fi
    return 0
}

STRUCT_JSON=$(run_json validate-structure.sh)
FRESH_JSON=$(run_json check-freshness.sh)
CONTENT_JSON=$(run_json verify-content.sh)
COMMANDS_JSON=$(run_json verify-commands.sh)

# Spine = the files validate-structure reports (it already excludes vendored
# example fixtures). Precompute a path -> line-count map for the Conciseness axis.
mapfile -t SPINE < <(printf '%s' "$STRUCT_JSON" | jq -r '(.files // [])[].path')

lines_pairs=()
for path in "${SPINE[@]}"; do
    full="$PROJECT_DIR/$path"
    n=0
    [[ -f "$full" ]] && n=$(wc -l < "$full" | tr -d ' ')
    lines_pairs+=("$(jq -nc --arg p "$path" --argjson n "$n" '{key:$p,value:$n}')")
done
if [[ "${#lines_pairs[@]}" -eq 0 ]]; then
    LINES_JSON='{}'
else
    LINES_JSON=$(printf '%s\n' "${lines_pairs[@]}" | jq -s 'from_entries')
fi

# --- Scoring (single jq pass; pure function of its inputs => reproducible) -----
SCORING=$(jq -nc \
    --argjson struct "$STRUCT_JSON" \
    --argjson fresh "$FRESH_JSON" \
    --argjson content "$CONTENT_JSON" \
    --argjson commands "$COMMANDS_JSON" \
    --argjson lines "$LINES_JSON" \
    --argjson review "$REVIEW_JSON" \
    '
    def clamp(max): if . < 0 then 0 elif . > max then max else . end;
    def grade(p): if p>=90 then "A" elif p>=75 then "B" elif p>=50 then "C" elif p>=30 then "D" else "F" end;
    def frac(r): if r=="strong" then 1.0 elif r=="adequate" then 0.6 else 0.2 end;

    ($fresh.files // [] | map({(.path): .}) | add // {}) as $fmap |
    ($commands.summary // {passed:0,skipped:0,failed:0}) as $cmd |
    (($cmd.passed // 0) + ($cmd.failed // 0)) as $cmdTotal |

    [ ($struct.files // [])[] |
      .path as $p | .role as $role |
      (.errors // 0) as $se | (.warnings // 0) as $sw |

      # Structure (25)
      ((25 - $se*5 - $sw*2) | clamp(25)) as $structure |

      # Currency (20)
      ($fmap[$p]) as $fr |
      ( if $fr == null then 8
        elif $fr.status == "fresh" then 20
        elif $fr.status == "unknown" then 8
        else ( ($fr.commits_since // 0) as $c |
               if $c <= 7 then 15 elif $c <= 14 then 11 elif $c <= 30 then 7 else 4 end )
        end ) as $currency |

      # Content (20) - issues attributed to this file
      ( [ ($content.issues // [])[] | select(.file == $p) ] ) as $ci |
      ( [ $ci[] | select(.severity=="ERROR") ] | length ) as $ce |
      ( [ $ci[] | select(.severity=="WARN")  ] | length ) as $cw |
      ((20 - $ce*5 - $cw*2) | clamp(20)) as $content_s |

      # Conciseness (20) - by role, from line count
      ($lines[$p] // 0) as $ln |
      ( if $role == "root"
        then ( if $ln<=50 then 20 elif $ln<=80 then 16 elif $ln<=150 then 10 else 5 end )
        else ( if $ln<=150 then 20 elif $ln<=250 then 15 else 8 end )
        end ) as $concise |

      # Commands (15) - root only, and only if there are verifiable commands
      ( if $role=="root" and $cmdTotal>0
        then { applies:true, score: (($cmd.passed*15/$cmdTotal)|floor) }
        else { applies:false, score:0 }
        end ) as $commands_axis |

      ( 25+20+20+20 + (if $commands_axis.applies then 15 else 0 end) ) as $maxApplicable |
      ( $structure+$currency+$content_s+$concise + $commands_axis.score ) as $earned |
      (($earned*100/$maxApplicable)|round) as $pct |

      # Optional qualitative overlay (non-reproducible): blend agent-judged LLM
      # axes (Architecture 10 / Actionability 8 / Non-obvious 7) into a secondary
      # grade. Only present when --review supplied a rating for this path.
      ($review[$p]) as $rv |
      ( if $rv == null then null
        else (frac($rv.architecture // "weak")*10
            + frac($rv.actionability // "weak")*8
            + frac($rv.non_obvious  // "weak")*7) end ) as $llm |
      ( if $llm == null then null
        else ((($earned + $llm) * 100 / ($maxApplicable + 25)) | round) end ) as $blended |

      { path:$p, role:$role, percent:$pct, grade: grade($pct),
        review: (if $rv == null then null
                 else {ratings:$rv, blended_percent:$blended, blended_grade:grade($blended)} end),
        axes: {
          structure:   {score:$structure,   max:25},
          currency:    {score:$currency,    max:20},
          content:     {score:$content_s,   max:20},
          conciseness: {score:$concise,     max:20},
          commands:    (if $commands_axis.applies then {score:$commands_axis.score, max:15} else {score:null, max:null, note:"n/a (scoped / no verifiable commands)"} end)
        }
      }
    ] | sort_by(.percent) as $files |
    ( [ $files[] | select(.review != null) ] ) as $reviewed |
    { schema:1,
      summary: {
        files: ($files|length),
        average: (if ($files|length)>0 then (([$files[].percent]|add)/($files|length))|round else 0 end),
        grade_counts: ($files | group_by(.grade) | map({(.[0].grade): length}) | add // {}),
        reviewed: ($reviewed|length),
        blended_average: (if ($reviewed|length)>0 then (([$reviewed[].review.blended_percent]|add)/($reviewed|length))|round else null end)
      },
      files: $files
    }
    ')

if [[ "$JSON" = true ]]; then
    printf '%s\n' "$SCORING" | jq .
    exit 0
fi

# --- Human report (rendered from the deterministic scoring document) ----------
printf '%s' "$SCORING" | jq -r '
    "AGENTS.md Quality Report  -  " + (.summary.files|tostring) + " file(s), average "
      + (.summary.average|tostring) + "/100   (worst-first)"
      + (if .summary.blended_average != null then "; with-review avg ~" + (.summary.blended_average|tostring) else "" end),
    "",
    ( .files[] |
      "  " + (.grade) + "  " + ((.percent|tostring)+"/100" | (. + (" " * (8 - (.|length)))))
        + "  " + .path,
      "       structure "  + (.axes.structure.score|tostring)  + "/25"
        + "  currency "    + (.axes.currency.score|tostring)    + "/20"
        + "  content "     + (.axes.content.score|tostring)     + "/20"
        + "  conciseness " + (.axes.conciseness.score|tostring) + "/20"
        + (if .axes.commands.score != null then "  commands " + (.axes.commands.score|tostring) + "/15" else "" end),
      ( if .review != null
        then "       with review: " + .review.blended_grade + " ~" + (.review.blended_percent|tostring)
             + "/100  (non-reproducible)"
        else empty end )
    )
'

echo ""
echo "Headline grades are deterministic (reproducible). Any 'with review' line is a"
echo "qualitative LLM overlay (non-reproducible) - see references/quality-rubric.md."
