import { Controller } from "@hotwired/stimulus"
import mermaid from "mermaid"

/**
 * Mermaidコントローラー
 *
 * Mermaid構文で記述された図表を動的に描画するStimulusコントローラー
 *
 * @class MermaidController
 * @extends Controller
 */
export default class extends Controller {
  static values = {
    code: String
  }

  /**
   * コントローラーが接続されたときに呼び出される
   *
   * @method connect
   * @memberof MermaidController
   */
  connect() {
    // mermaidの初期化
    mermaid.initialize({
      startOnLoad: false,
      securityLevel: 'strict',
      fontFamily: 'ui-sans-serif, system-ui, sans-serif',
    })

    this.renderDiagram()

    // ダークモード切り替えイベントをリッスン
    this.themeChangeHandler = this.handleThemeChange.bind(this)
    window.addEventListener('theme-changed', this.themeChangeHandler)
  }

  /**
   * コントローラーが切断されたときに呼び出される
   *
   * @method disconnect
   * @memberof MermaidController
   */
  disconnect() {
    // イベントリスナーを削除
    window.removeEventListener('theme-changed', this.themeChangeHandler)
  }

  /**
   * テーマ変更時に図表を再描画する
   *
   * @method handleThemeChange
   * @memberof MermaidController
   * @param {CustomEvent} event - テーマ変更イベント
   */
  handleThemeChange(event) {
    console.log(event);
    // テーマに応じてmermaidの設定を更新
    mermaid.initialize({
      startOnLoad: false,
      securityLevel: 'strict',
      fontFamily: 'ui-sans-serif, system-ui, sans-serif',
    })

    // 図表を再描画
    this.renderDiagram()
  }

  /**
   * Mermaid図表を描画する
   *
   * @method renderDiagram
   * @memberof MermaidController
   */
  renderDiagram() {
    const renderTarget = this.element.querySelector('.mermaid-render')
    const source = this.element.querySelector('.mermaid-source').textContent

    try {
      // mermaidを使用して図表を描画
      mermaid.render('mermaid-svg-' + Date.now(), source)
        .then(result => {
          renderTarget.innerHTML = result.svg
        })
        .catch(error => {
          console.error('Mermaid rendering error:', error)
          renderTarget.innerHTML = `<div class="p-4 bg-red-50 text-red-500 rounded">
            図表の描画に失敗しました: ${error.message}
          </div>`
        })
    } catch (error) {
      console.error('Mermaid error:', error)
      renderTarget.innerHTML = `<div class="p-4 bg-red-50 text-red-500 rounded">
        図表の描画に失敗しました: ${error.message}
      </div>`
    }
  }
}
