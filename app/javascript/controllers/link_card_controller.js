/**
 * リンクカードコントローラー
 *
 * URLからメタデータを取得し、リンクカードとして表示するStimulusコントローラー
 *
 * @class LinkCardController
 * @extends Controller
 */
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,
    label: String
  }

  /**
   * コントローラーが接続されたときに呼び出される
   *
   * @method connect
   * @memberof LinkCardController
   */
  connect() {
    // コントローラーが接続されたらメタデータを取得
    this.fetchMetadata()
  }

  /**
   * URLからメタデータを取得する
   *
   * @method fetchMetadata
   * @memberof LinkCardController
   * @async
   * @returns {Promise<void>}
   */
  async fetchMetadata() {
    try {
      // APIエンドポイントにリクエスト
      const response = await fetch(`/api/link_cards/metadata?url=${encodeURIComponent(this.urlValue)}`)

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }

      const data = await response.json()

      // 取得したメタデータでリンクカードを生成
      this.renderLinkCard(data)
    } catch (error) {
      console.error("Error fetching link metadata:", error)
      // エラー時は元のリンクをそのまま表示(すでに表示されている)
    }
  }

  /**
   * 取得したメタデータでリンクカードを描画する
   *
   * @method renderLinkCard
   * @memberof LinkCardController
   * @param {Object} data - メタデータオブジェクト
   * @param {string} data.title - ページのタイトル
   * @param {string} data.description - ページの説明
   * @param {string} data.domain - ドメイン名
   * @param {string} data.favicon - ファビコンのURL
   * @param {string} data.imageUrl - 画像のURL
   */
  renderLinkCard(data) {
    // リンクカードのHTMLを生成
    const html = this.generateCardHTML(data)

    // 現在の要素を置き換え
    this.element.outerHTML = html
  }

  /**
   * メタデータからリンクカードのHTMLを生成する
   *
   * @method generateCardHTML
   * @memberof LinkCardController
   * @param {Object} data - メタデータオブジェクト
   * @param {string} data.title - ページのタイトル
   * @param {string} data.description - ページの説明
   * @param {string} data.domain - ドメイン名
   * @param {string} data.favicon - ファビコンのURL
   * @param {string} data.imageUrl - 画像のURL
   * @returns {string} 生成されたHTML
   */
  generateCardHTML(data) {
    const { title, description, domain, favicon, imageUrl } = data

    return `
      <div class="my-6">
        ${this.hasLabelValue ? `
        <!-- ラベル -->
        <div class="flex items-center gap-2 mb-2">
          <svg class="w-4 h-4 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"></path>
          </svg>
          <span class="text-sm font-semibold text-gray-700">${this.escapeHtml(this.labelValue)}</span>
        </div>
        ` : ''}

        <!-- リンクカード -->
        <a href="${this.urlValue}" target="_blank" rel="noopener"
           class="group block overflow-hidden border-2 border-blue-100 rounded-lg shadow-sm hover:shadow-lg hover:border-blue-200 transition-all duration-200 bg-gradient-to-br from-blue-50 to-white">
          <div class="flex flex-row items-stretch">
            <!-- 画像（左側） -->
            ${imageUrl ?
              `<div class="w-48 flex-shrink-0 bg-gray-100 overflow-hidden">
                <img src="${imageUrl}" alt="" class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-200" onerror="this.parentElement.style.display='none'">
              </div>` : ''
            }

            <!-- コンテンツ部分 -->
            <div class="flex-1 p-5 min-w-0">
              <h3 class="text-lg font-bold text-gray-900 mb-2 line-clamp-2 group-hover:text-blue-700 transition-colors">${this.escapeHtml(title || this.urlValue)}</h3>
              ${description ? `<p class="text-sm text-gray-600 mb-3 line-clamp-3">${this.escapeHtml(description)}</p>` : ''}
              <div class="flex items-center text-gray-500">
                ${favicon ?
                  `<img src="${favicon}" alt="" class="w-4 h-4 mr-2" onerror="this.style.display='none'">` :
                  `<div class="w-4 h-4 mr-2 bg-blue-500 rounded-sm flex items-center justify-center text-white text-xs font-bold">${domain ? domain[0].toUpperCase() : ''}</div>`
                }
                <span class="text-sm truncate">${this.escapeHtml(domain)}</span>
                <svg class="w-4 h-4 ml-2 text-gray-400 group-hover:text-blue-600 transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"></path>
                </svg>
              </div>
            </div>
          </div>
        </a>
      </div>
    `
  }

  /**
   * HTMLエスケープ処理
   *
   * @method escapeHtml
   * @memberof LinkCardController
   * @param {string} text - エスケープするテキスト
   * @returns {string} エスケープされたテキスト
   */
  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}
