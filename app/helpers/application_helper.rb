module ApplicationHelper
  def google_analytics_tag
    measurement_id = ENV["GA_MEASUREMENT_ID"]
    return if measurement_id.blank?

    content_tag(:script, nil, async: true, src: "https://www.googletagmanager.com/gtag/js?id=#{measurement_id}") +
    javascript_tag(<<~JS, nonce: true)
      window.dataLayer = window.dataLayer || [];
      function gtag(){dataLayer.push(arguments);}
      gtag('js', new Date());
      gtag('config', '#{measurement_id}', { send_page_view: false });

      // 初回ページビュー送信
      gtag('event', 'page_view', {
        page_path: window.location.pathname,
        page_location: window.location.href,
        page_title: document.title
      });

      // Turbo Drive対応: ページ遷移時にページビューを送信
      let isInitialLoad = true;
      document.addEventListener('turbo:load', function() {
        if (isInitialLoad) {
          isInitialLoad = false;
          return;
        }
        gtag('event', 'page_view', {
          page_path: window.location.pathname,
          page_location: window.location.href,
          page_title: document.title
        });
      });
    JS
  end
end
