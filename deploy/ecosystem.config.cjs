module.exports = {
  apps: [
    {
      name: 'inventory-api',
      cwd: '/opt/inventoryinonetap/backend',
      script: 'server.js',
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: '512M',
      env: {
        NODE_ENV: 'production',
        PORT: 5000,
      },
    },
  ],
};
