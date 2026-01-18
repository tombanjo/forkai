class AIChatInterface extends HTMLElement {
  constructor() {
    super();
    this.attachShadow({ mode: 'open' });
    this._data = null; // Private property to store data
  }

  static get observedAttributes() {
    return ['include-input', 'include-output'];
  }

  async attributeChangedCallback(name, oldValue, newValue) {
    if ((name === 'include-input' || name === 'include-output') && this.shadowRoot) {
      await this.render();
      this.attachEventListeners();
    }
  }

  set data(value) {
    this._data = value;
    this.fetchChatResponse(); // Trigger fetchChatResponse when data is updated
  }

  get data() {
    return this._data;
  }

  async connectedCallback() {
    await this.render();
    this.attachEventListeners();
  }

  async render() {
    const hasInput = this.hasAttribute('include-input');
    const hasOutput = this.hasAttribute('include-output');
    
    // Don't render anything if both attributes are false
    if (!hasInput && !hasOutput) {
      this.shadowRoot.innerHTML = '';
      return;
    }
    
    // Get the stylesheet path relative to the component
    const componentPath = new URL(import.meta.url).pathname;
    const stylesPath = componentPath.replace('/web-component/ai-chat-interface.js', '/styles.css');
    
    // Fetch and inject the stylesheet
    let stylesContent = '';
    try {
      const response = await fetch(stylesPath);
      if (response.ok) {
        stylesContent = await response.text();
      }
    } catch (error) {
      console.warn('Could not load external stylesheet, using inline styles:', error);
      // Fallback to inline styles if fetch fails
      stylesContent = `
        .ai-chat-container {
          font-family: Arial, sans-serif;
          padding: 10px;
          border: 1px solid #ccc;
          border-radius: 5px;
          max-width: 300px;
        }
        .ai-chat-message {
          margin-bottom: 10px;
        }
        .ai-chat-response {
          color: blue;
          margin-bottom: 10px;
        }
        .ai-chat-response-error {
          color: red;
        }
        .ai-chat-input-container {
          margin-top: 10px;
        }
        .ai-chat-input-container textarea {
          width: 100%;
          padding: 5px;
          margin-bottom: 5px;
          box-sizing: border-box;
        }
        .ai-chat-input-container button {
          padding: 5px 10px;
          margin-right: 5px;
          cursor: pointer;
        }
      `;
    }
    
    this.shadowRoot.innerHTML = `
      <style>
        ${stylesContent}
      </style>
      <div class="ai-chat-container">
        ${hasOutput ? `
          <div class="ai-chat-message">Welcome to AI Chat Interface!</div>
          <div class="ai-chat-response">Loading response...</div>
        ` : ''}
        ${hasInput ? `
          <div class="ai-chat-input-container">
            <textarea id="internalInputBox" placeholder="Enter your message here..." rows="10" cols="30"></textarea>
            <br>
            <button id="internalSubmitButton">Submit</button>
            <button id="internalClearButton">Clear</button>
          </div>
        ` : ''}
      </div>
    `;
  }

  attachEventListeners() {
    if (this.hasAttribute('include-input')) {
      const inputBox = this.shadowRoot.getElementById('internalInputBox');
      const submitButton = this.shadowRoot.getElementById('internalSubmitButton');
      const clearButton = this.shadowRoot.getElementById('internalClearButton');

      if (submitButton) {
        submitButton.addEventListener('click', () => {
          const data = inputBox.value;
          if (data.trim()) {
            this.data = { message: data };
          }
        });
      }

      if (clearButton) {
        clearButton.addEventListener('click', () => {
          inputBox.value = '';
          this.data = { message: '' };
        });
      }
    }
  }

  async fetchChatResponse() {
    try {
      // Skip if data is empty or invalid
      if (!this._data || (typeof this._data === 'object' && !this._data.message)) {
        return;
      }
      
      const response = await fetch('https://chat-service-pyztkecy2q-uc.a.run.app/', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(this._data), // Send the updated data as JSON
      });
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      
      const data = await response.json();
      const reply = data.reply || data.message || JSON.stringify(data);
      const modelProvider = data.debug?.modelProvider || null;
      
      // Update embedded output if it exists
      if (this.hasAttribute('include-output')) {
        const responseElement = this.shadowRoot.querySelector('.ai-chat-response');
        if (responseElement) {
          // Render markdown if available
          responseElement.innerHTML = this.renderMarkdown(reply);
        }
      }
      
      // Dispatch message event
      this.dispatchEvent(new CustomEvent('message', {
        detail: { message: reply, modelProvider },
        bubbles: true,
        composed: true
      }));
    } catch (error) {
      // Update embedded output if it exists
      if (this.hasAttribute('include-output')) {
        const responseElement = this.shadowRoot.querySelector('.ai-chat-response');
        if (responseElement) {
          responseElement.innerHTML = 'Failed to fetch response.';
          responseElement.classList.add('ai-chat-response-error');
        }
      }
      console.error('Error fetching chat response:', error);
      
      // Dispatch error event
      this.dispatchEvent(new CustomEvent('error', {
        detail: error.message,
        bubbles: true,
        composed: true
      }));
    }
  }

  renderMarkdown(text) {
    if (!text) return '';
    
    // Simple markdown parser for common patterns
    let html = text
      // Escape HTML first
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      // Headers
      .replace(/^### (.*$)/gim, '<h3>$1</h3>')
      .replace(/^## (.*$)/gim, '<h2>$1</h2>')
      .replace(/^# (.*$)/gim, '<h1>$1</h1>')
      // Bold
      .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
      .replace(/__(.+?)__/g, '<strong>$1</strong>')
      // Italic
      .replace(/\*(.+?)\*/g, '<em>$1</em>')
      .replace(/_(.+?)_/g, '<em>$1</em>')
      // Code blocks
      .replace(/```([\s\S]*?)```/g, '<pre><code>$1</code></pre>')
      // Inline code
      .replace(/`(.+?)`/g, '<code>$1</code>')
      // Links
      .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank" rel="noopener">$1</a>')
      // Line breaks
      .replace(/\n\n/g, '</p><p>')
      .replace(/\n/g, '<br>');
    
    // Wrap in paragraph if not already wrapped
    if (!html.startsWith('<h') && !html.startsWith('<pre') && !html.startsWith('<p>')) {
      html = '<p>' + html + '</p>';
    }
    
    return html;
  }
}

customElements.define('ai-chat-interface', AIChatInterface);
