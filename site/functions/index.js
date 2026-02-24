const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin
admin.initializeApp();

// Automatically import all function modules from utils folder
const utilsPath = path.join(__dirname, 'utils');
const functionModules = {};

// Read all files in utils directory
const files = fs.readdirSync(utilsPath);

// Import each .js file and merge their exports
files.forEach(file => {
  if (file.endsWith('.js')) {
    const moduleName = path.basename(file, '.js');
    const modulePath = path.join(utilsPath, file);
    const moduleExports = require(modulePath);
    
    // Merge all exports from this module
    Object.assign(functionModules, moduleExports);
  }
});

// Export all functions
module.exports = functionModules;
