const { defineConfig } = require('@vue/cli-service')

module.exports = defineConfig({
  transpileDependencies: true,
  devServer: {
    proxy: {
      '^/api': {
        target: 'http://localhost:3001',
        // target: 'https://spd-demo.dtc.co.th:2568',
        changeOrigin: true,
        logLevel: 'debug',
        pathRewrite: { '^/api': '' },
      },
    },
    client: {
      overlay: {
        // สั่งให้ไม่ต้องโชว์ Error เฉพาะตัวที่กวนใจนี้
        runtimeErrors: (error) => {
          if (error.message === 'ResizeObserver loop completed with undelivered notifications.') {
            return false;
          }
          return true;
        },
      },
    },
  },
  chainWebpack: config => {
    config.plugins.delete('copy')
    config.plugin('copy').use(require('copy-webpack-plugin'), [
      {
        patterns: [
          {
            from: 'public',
            globOptions: {
              ignore: ['**/index.html']
            }
          }
        ]
      }
    ])
  }
})
