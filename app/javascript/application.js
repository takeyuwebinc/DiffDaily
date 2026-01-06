// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import mermaid from "mermaid"
import hljs from "highlight.js"

// Initialize Mermaid
document.addEventListener('DOMContentLoaded', () => {
  mermaid.initialize({ startOnLoad: true, theme: 'default' });
});

// Make hljs globally available for the Stimulus controller
window.hljs = hljs;
