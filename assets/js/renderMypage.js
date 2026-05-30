export async function renderMypage(root) {
  root.innerHTML = `
    <header class="page-title">
      <div class="eyebrow">Account</div>
      <h1>マイページ</h1>
      <p class="lead">アカウント機能は準備中です。</p>
    </header>
    <section class="section">
      <article class="article-box">
        <h2>現在準備中です。</h2>
        <p>今後、ログイン状態・参加申請中のセッション・参加予定セッションを確認できるようにする予定です。</p>
        <p>ログイン機能、ログアウト機能、参加申請一覧はまだ利用できません。</p>
        <p>
          <a class="button primary" href="index.html">トップへ戻る</a>
          <a class="button" href="calendar.html">CALENDARへ戻る</a>
        </p>
      </article>
      <article class="article-box">
        <h2>アカウント機能</h2>
        <p>ログイン・ログアウト、参加申請一覧、参加予定セッションの確認は今後対応予定です。</p>
        <p>現在は接続設定が未構成のため、Supabaseには接続していません。</p>
      </article>
    </section>
  `;
}
