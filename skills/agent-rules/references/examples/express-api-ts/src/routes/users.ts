import { Router } from 'express';
import { UserController } from '../controllers/userController.js';

const router = Router();
const controller = new UserController();

router.get('/', controller.getAll);
router.get('/:id', controller.getById);
router.post('/', controller.create);
router.put('/:id', controller.update);
router.delete('/:id', controller.delete);

export { router as userRoutes };
