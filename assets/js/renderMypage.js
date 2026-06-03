export async function renderMypage(root) {
  root.innerHTML = `
    <header class="page-title">
      <div class="eyebrow">Account</div>
      <h1>マイページ</h1>
      <p class="lead">ログイン、ユーザー名、参加申請中・参加予定セッションを確認できます。</p>
    </header>
    <section class="section">
      <article class="article-box">
        <h2>アカウントと参加状況</h2>
        <p>ログインすると、ユーザー名の確認・変更と、参加申請中・参加予定セッションの確認ができます。</p>
        <p>参加希望コメントの投稿やGM承認操作は、今後の工程で対応予定です。</p>
        <p>
          <a class="button primary" href="index.html">トップへ戻る</a>
          <a class="button" href="calendar.html">CALENDARへ戻る</a>
        </p>
      </article>
      <article class="article-box" data-mypage-auth-section>
        <h2>アカウント機能</h2>
        <p data-mypage-auth-primary>アカウント機能は準備中です。</p>
        <p data-mypage-auth-detail>接続設定が未構成のため、Supabaseには接続していません。</p>
      </article>
    </section>
  `;

  if (window.VELGARD_MYPAGE_AUTH && typeof window.VELGARD_MYPAGE_AUTH.init === "function") {
    await window.VELGARD_MYPAGE_AUTH.init(root);
  }
}
