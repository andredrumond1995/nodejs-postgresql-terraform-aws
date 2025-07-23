import 'reflect-metadata';
import express from 'express';
import { AppDataSource } from './data-source';
import { Todo } from './todo.entity';

const app = express();
const port = process.env.PORT || 3000;
app.use(express.json());

AppDataSource.initialize().then(() => {
  // GET /todos - returns all TODOs from the database
  app.get('/todos', async (req, res) => {
    const todos = await AppDataSource.getRepository(Todo).find();
    res.json({ success: true, data: todos });
  });

  // POST /todos - adds a new TODO
  app.post('/todos', async (req, res) => {
    const { title } = req.body;
    if (!title) {
      return res.status(400).json({ success: false, message: 'Title is required' });
    }
    const todo = AppDataSource.getRepository(Todo).create(req.body);
    await AppDataSource.getRepository(Todo).save(todo);
    res.status(201).json({ success: true, data: todo });
  });

  app.listen(port, () => {
    console.log(`Server running at http://localhost:${port}`);
  });
}).catch((error) => {
  console.error('Error connecting to the database:', error);
}); 