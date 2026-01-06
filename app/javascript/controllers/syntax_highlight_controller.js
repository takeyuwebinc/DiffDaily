import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="syntax-highlight"
export default class extends Controller {
  connect() {
    // highlight.jsが読み込まれるまで待機
    this.waitForHighlightJs()
  }

  waitForHighlightJs() {
    if (typeof hljs !== 'undefined') {
      this.highlightAll()
    } else {
      // highlight.jsが読み込まれるまで少し待つ
      setTimeout(() => this.waitForHighlightJs(), 100)
    }
  }

  highlightAll() {
    // コードブロックを検索してハイライトを適用
    const codeBlocks = this.element.querySelectorAll('pre code')

    codeBlocks.forEach(block => {
      // 既にハイライト済みかチェック
      if (!block.classList.contains('hljs')) {
        hljs.highlightElement(block)
      }

      // コピーボタンを追加
      this.addCopyButton(block.parentElement)
    })

    console.log("Syntax highlighting applied to", codeBlocks.length, "code blocks")
  }

  addCopyButton(preElement) {
    // 既にコピーボタンが存在する場合はスキップ
    if (preElement.querySelector('.copy-button')) {
      return
    }

    // コピーボタンを作成
    const copyButton = document.createElement('button')
    copyButton.className = 'copy-button'
    copyButton.style.cssText = `
      position: absolute;
      top: 6px;
      right: 6px;
      padding: 3px 6px;
      font-size: 11px;
      line-height: 1.2;
      background-color: rgba(55, 65, 81, 0.9);
      color: white;
      border: 1px solid rgba(75, 85, 99, 0.5);
      border-radius: 3px;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 3px;
      transition: all 0.2s ease;
      z-index: 10;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      height: 22px;
      width: 66px;
      min-width: 60px;
    `

    copyButton.innerHTML = `
      <svg width="12" height="12" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"></path>
      </svg>
      <span>Copy</span>
    `

    // ホバー効果を追加
    copyButton.addEventListener('mouseenter', () => {
      copyButton.style.backgroundColor = 'rgba(75, 85, 99, 0.9)'
      copyButton.style.borderColor = 'rgba(107, 114, 128, 0.7)'
    })

    copyButton.addEventListener('mouseleave', () => {
      copyButton.style.backgroundColor = 'rgba(55, 65, 81, 0.9)'
      copyButton.style.borderColor = 'rgba(75, 85, 99, 0.5)'
    })

    copyButton.setAttribute('data-action', 'click->syntax-highlight#copyCode')
    copyButton.setAttribute('data-syntax-highlight-target', 'copyButton')

    // preElementを相対位置に設定
    preElement.style.position = 'relative'

    // コピーボタンを追加
    preElement.appendChild(copyButton)
  }

  copyCode(event) {
    const button = event.currentTarget
    const preElement = button.parentElement
    const codeElement = preElement.querySelector('code')

    if (!codeElement) return

    // コードテキストを取得
    const codeText = codeElement.textContent

    // クリップボードにコピー
    navigator.clipboard.writeText(codeText).then(() => {
      // 成功時のフィードバック
      this.showCopyFeedback(button, 'Copied!')
    }).catch(() => {
      // フォールバック: 古いブラウザ対応
      this.fallbackCopyToClipboard(codeText, button)
    })
  }

  fallbackCopyToClipboard(text, button) {
    const textArea = document.createElement('textarea')
    textArea.value = text
    textArea.style.position = 'fixed'
    textArea.style.left = '-999999px'
    textArea.style.top = '-999999px'
    document.body.appendChild(textArea)
    textArea.focus()
    textArea.select()

    try {
      document.execCommand('copy')
      this.showCopyFeedback(button, 'Copied!')
    } catch (err) {
      this.showCopyFeedback(button, 'Failed to copy')
    }

    document.body.removeChild(textArea)
  }

  showCopyFeedback(button, message) {
    const originalHTML = button.innerHTML
    const originalStyle = button.style.backgroundColor

    // アイコンを変更（幅は固定されているので変わらない）
    button.innerHTML = `
      <svg width="12" height="12" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
      </svg>
      <span>${message}</span>
    `
    button.style.backgroundColor = 'rgba(34, 197, 94, 0.9)'
    button.style.borderColor = 'rgba(34, 197, 94, 0.7)'

    // 2秒後に元に戻す
    setTimeout(() => {
      button.innerHTML = originalHTML
      button.style.backgroundColor = originalStyle
      button.style.borderColor = 'rgba(75, 85, 99, 0.5)'
    }, 2000)
  }

  // 動的にコンテンツが追加された場合の再ハイライト
  refresh() {
    this.highlightAll()
  }
}
