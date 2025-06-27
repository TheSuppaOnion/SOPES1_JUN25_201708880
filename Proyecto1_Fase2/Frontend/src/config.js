const config = {
  // WebSocket URL
  WEBSOCKET_URL: process.env.REACT_APP_WEBSOCKET_URL || '/websocket',
    
  API_URL: process.env.REACT_APP_API_URL || '/api',
    
  API_PYTHON_URL: process.env.REACT_APP_API_PYTHON_URL || '/api-python',
    
  API_NODEJS_URL: process.env.REACT_APP_API_NODEJS_URL || '/api'
};

export default config;