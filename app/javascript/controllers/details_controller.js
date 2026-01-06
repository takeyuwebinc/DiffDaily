import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]

  connect() {
    // 初期状態では内容を非表示にする
    this.contentTarget.classList.add("hidden")
  }

  toggle(event) {
    // ボタンがクリックされたときに内容の表示/非表示を切り替える
    this.contentTarget.classList.toggle("hidden")

    // 矢印アイコンの回転を切り替える(閉じているときは下向き、開いているときは上向き)
    const iconElement = event.currentTarget.querySelector("svg")
    iconElement.classList.toggle("rotate-180")
  }
}
