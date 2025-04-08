/**
 * Next.js 메인 페이지 컴포넌트
 * 
 * 이 컴포넌트는 애플리케이션의 홈페이지를 렌더링합니다.
 * - 현재 Node.js 버전 표시
 * - 실행 환경 정보 표시
 */
export default function Home() {
  return (
    <div style={{ padding: '20px' }}>
      <h1>Next.js 데모 애플리케이션</h1>
      <p>Docker 환경에서 실행 중인 Next.js 데모 앱입니다!</p>
      
      {/* 환경 정보 표시 섹션 */}
      <div>
        <h2>환경 정보:</h2>
        <pre>
          {JSON.stringify({
            nodeVersion: process.version,        // Node.js 버전
            environment: process.env.NODE_ENV    // 실행 환경 (development/production)
          }, null, 2)}
        </pre>
      </div>
    </div>
  );
}
