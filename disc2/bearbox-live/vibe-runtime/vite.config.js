import { defineConfig } from 'vite';
import basicSsl from '@vitejs/plugin-basic-ssl';

export default defineConfig({
  plugins: [basicSsl()],
  server: {
    host: '0.0.0.0',
    port: 5173,
    proxy: {
      '/patch': 'http://127.0.0.1:8787',
      '/patch-ws': {
        target: 'ws://127.0.0.1:8787',
        ws: true
      }
    }
  }
});
