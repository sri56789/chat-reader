'use client';
import { useState, useRef, useEffect } from 'react';

interface Message {
  role: 'user' | 'assistant';
  content: string;
}

export default function Home() {
  const [input, setInput] = useState('');
  const [messages, setMessages] = useState<Message[]>([]);
  const [loading, setLoading] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const ask = async () => {
    if (!input.trim() || loading) return;

    const userMessage: Message = { role: 'user', content: input };
    setMessages(prev => [...prev, userMessage]);
    setInput('');
    setLoading(true);

    try {
      // Use relative URL since we're served from the same server
      const res = await fetch('/api/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ question: userMessage.content })
      });
      
      if (!res.ok) {
        throw new Error('Failed to get response');
      }
      
      const data = await res.json();
      const assistantMessage: Message = { role: 'assistant', content: data.answer };
      setMessages(prev => [...prev, assistantMessage]);
    } catch (error) {
      const errorMessage: Message = { 
        role: 'assistant', 
        content: 'Sorry, I encountered an error. Please make sure the backend is running and PDFs are loaded.' 
      };
      setMessages(prev => [...prev, errorMessage]);
    } finally {
      setLoading(false);
    }
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      ask();
    }
  };

  const reloadDocuments = async () => {
    try {
      // Use relative URL since we're served from the same server
      const res = await fetch('/api/reload', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
      });
      if (res.ok) {
        const data = await res.json();
        alert(`PDFs reloaded successfully! Loaded ${data.chunks || 0} text chunks.`);
      } else {
        const data = await res.json();
        alert(`Failed to reload PDFs: ${data.status || 'Unknown error'}`);
      }
    } catch (error) {
      alert('Failed to reload PDFs. Make sure the backend is running on port 8080.');
    }
  };

  return (
    <main style={styles.container}>
      <div style={styles.header}>
        <h1 style={styles.title}>📄 PDF Chatbot</h1>
        <button onClick={reloadDocuments} style={styles.reloadButton}>
          🔄 Reload PDFs
        </button>
      </div>

      <div style={styles.chatContainer}>
        {messages.length === 0 && (
          <div style={styles.welcomeMessage}>
            <p>👋 Welcome! Ask me anything about the PDFs in the <code>pdfs</code> folder.</p>
            <p style={styles.hint}>Place your PDF files in the <code>pdfs</code> folder and click "Reload PDFs" to get started.</p>
          </div>
        )}
        
        {messages.map((msg, idx) => (
          <div
            key={idx}
            style={{
              ...styles.message,
              ...(msg.role === 'user' ? styles.userMessage : styles.assistantMessage)
            }}
          >
            <div style={styles.messageContent}>
              <strong>{msg.role === 'user' ? 'You' : 'Assistant'}:</strong>
              <div style={styles.messageText}>{msg.content}</div>
            </div>
          </div>
        ))}
        
        {loading && (
          <div style={{ ...styles.message, ...styles.assistantMessage }}>
            <div style={styles.messageContent}>
              <strong>Assistant:</strong>
              <div style={styles.messageText}>Thinking...</div>
            </div>
          </div>
        )}
        <div ref={messagesEndRef} />
      </div>

      <div style={styles.inputContainer}>
        <textarea
          value={input}
          onChange={e => setInput(e.target.value)}
          onKeyPress={handleKeyPress}
          placeholder="Ask a question about your PDFs..."
          style={styles.textarea}
          rows={3}
          disabled={loading}
        />
        <button
          onClick={ask}
          disabled={loading || !input.trim()}
          style={{
            ...styles.sendButton,
            ...(loading || !input.trim() ? styles.sendButtonDisabled : {})
          }}
        >
          Send
        </button>
      </div>
    </main>
  );
}

const styles = {
  container: {
    display: 'flex',
    flexDirection: 'column' as const,
    height: '100vh',
    maxWidth: '1200px',
    margin: '0 auto',
    padding: '20px',
    fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
    backgroundColor: '#f5f5f5',
  },
  header: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '20px',
    padding: '20px',
    backgroundColor: 'white',
    borderRadius: '10px',
    boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
  },
  title: {
    margin: 0,
    fontSize: '28px',
    color: '#333',
  },
  reloadButton: {
    padding: '10px 20px',
    backgroundColor: '#007bff',
    color: 'white',
    border: 'none',
    borderRadius: '5px',
    cursor: 'pointer',
    fontSize: '14px',
    fontWeight: 'bold',
  },
  chatContainer: {
    flex: 1,
    overflowY: 'auto' as const,
    padding: '20px',
    backgroundColor: 'white',
    borderRadius: '10px',
    marginBottom: '20px',
    boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
  },
  welcomeMessage: {
    textAlign: 'center' as const,
    color: '#666',
    padding: '40px 20px',
  },
  hint: {
    fontSize: '14px',
    marginTop: '10px',
    color: '#999',
  },
  message: {
    marginBottom: '20px',
    padding: '15px',
    borderRadius: '10px',
    maxWidth: '80%',
  },
  userMessage: {
    backgroundColor: '#007bff',
    color: 'white',
    marginLeft: 'auto',
    textAlign: 'right' as const,
  },
  assistantMessage: {
    backgroundColor: '#e9ecef',
    color: '#333',
    marginRight: 'auto',
  },
  messageContent: {
    wordWrap: 'break-word' as const,
  },
  messageText: {
    marginTop: '5px',
    whiteSpace: 'pre-wrap' as const,
  },
  inputContainer: {
    display: 'flex',
    gap: '10px',
    padding: '20px',
    backgroundColor: 'white',
    borderRadius: '10px',
    boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
  },
  textarea: {
    flex: 1,
    padding: '15px',
    border: '2px solid #ddd',
    borderRadius: '5px',
    fontSize: '16px',
    fontFamily: 'inherit',
    resize: 'none' as const,
  },
  sendButton: {
    padding: '15px 30px',
    backgroundColor: '#007bff',
    color: 'white',
    border: 'none',
    borderRadius: '5px',
    cursor: 'pointer',
    fontSize: '16px',
    fontWeight: 'bold',
  },
  sendButtonDisabled: {
    backgroundColor: '#ccc',
    cursor: 'not-allowed',
  },
};