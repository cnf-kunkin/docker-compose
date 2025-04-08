import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

/**
 * Nest.js 애플리케이션 부트스트랩 함수
 * 
 * 이 함수는 Nest.js 애플리케이션을 초기화하고 시작합니다.
 * 1. NestFactory를 사용하여 AppModule 기반의 애플리케이션 생성
 * 2. 3000번 포트에서 HTTP 서버 시작
 */
async function bootstrap() {
  // AppModule을 기반으로 Nest.js 애플리케이션 인스턴스 생성
  const app = await NestFactory.create(AppModule, {
    // 로그 레벨 설정
    logger: ['error', 'warn', 'log'],
  });

  // CORS 설정
  app.enableCors({
    origin: process.env.ALLOWED_ORIGINS?.split(',') || '*',
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE',
    credentials: true,
  });

  // 환경변수에서 포트 가져오기 (기본값: 3000)
  const port = process.env.PORT || 3000;
  
  // 서버 시작
  await app.listen(port);
  console.log(`애플리케이션이 ${port}번 포트에서 실행 중입니다.`);
}

// 애플리케이션 시작
bootstrap();
