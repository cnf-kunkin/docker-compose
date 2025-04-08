import { Controller, Get } from '@nestjs/common';

@Controller()
export class AppController {
  @Get()
  getHello(): any {
    return {
      message: 'Nest.js Demo Application',
      info: {
        nodeVersion: process.version,
        environment: process.env.NODE_ENV
      }
    };
  }
}
