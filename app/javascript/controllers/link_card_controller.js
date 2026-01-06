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
    url: String
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
      <div class="my-4">
        <a href="${this.urlValue}" target="_blank" rel="noopener" class="block overflow-hidden no-underline border border-gray-200 rounded-lg shadow-sm hover:shadow-md transition-shadow duration-200 bg-white dark:bg-zinc-800 dark:border-zinc-700">
          <div class="flex flex-row items-stretch">
            <div class="flex-1 p-4 overflow-hidden">
              <h3 class="text-lg font-bold text-zinc-800 dark:text-zinc-100 mb-1 line-clamp-2">${title || this.urlValue}</h3>
              ${description ? `<p class="text-sm text-zinc-600 dark:text-zinc-400 mb-2 line-clamp-2">${description}</p>` : ''}
              <div class="flex items-center">
                ${favicon ?
                  `<img src="${favicon}" alt="" class="w-4 h-4 mr-2" onerror="this.style.display='none'">` :
                  `<div class="w-4 h-4 mr-2 bg-blue-500 rounded-sm flex items-center justify-center text-white text-xs">${domain ? domain[0].toUpperCase() : ''}</div>`
                }
                <span class="text-sm text-zinc-500 dark:text-zinc-500 truncate">${domain}</span>
              </div>
            </div>
            ${imageUrl ?
              `<div class="w-1/3 max-w-[240px] bg-gray-100 dark:bg-zinc-700">
                <div class="relative h-full">
                  <img src="${imageUrl}" alt="" class="absolute inset-0 w-full h-full object-cover" onerror="this.style.display='none'">
                </div>
              </div>` : ''
            }
          </div>
        </a>
      </div>
    `
  }
}
