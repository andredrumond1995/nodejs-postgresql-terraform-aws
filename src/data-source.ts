import 'reflect-metadata';
import { DataSource, DataSourceOptions } from 'typeorm';
import { Todo } from './todo.entity';

function getDBConfig() {
  const config: DataSourceOptions = {
    type: 'postgres',
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '5432', 10),
    username: process.env.DB_USER,
    password: process.env.DB_PASS,
    database: process.env.DB_NAME,
    synchronize: true,
    logging: false,
    entities: [Todo],
  };

  if (process.env.NODE_ENV === 'production') {
    return { ...config, synchronize: false, ssl: { rejectUnauthorized: false } };
  }

  return config;
}
export const AppDataSource = new DataSource(getDBConfig()); 