const config = {
  WEBSOCKET_URL: process.env.REACT_APP_WEBSOCKET_URL || 
    (window.location.protocol === 'https:' ? 'wss://' : 'ws://') + 
    window.location.hostname + ':4001',  
    
  API_URL: process.env.REACT_APP_API_URL || 
    window.location.protocol + '//' + window.location.hostname + ':3001',  
    
  // URLs para testing de traffic split
  API_PYTHON_URL: process.env.REACT_APP_API_PYTHON_URL || 
    window.location.protocol + '//' + window.location.hostname + ':5001',  
    
  API_NODEJS_URL: process.env.REACT_APP_API_NODEJS_URL || 
    window.location.protocol + '//' + window.location.hostname + ':3001'  
};

export default config;