// Firebase configuration for both projects
const FirebaseConfigs = {
  // Club project configuration
  club: {
    apiKey: "AIzaSyAS_vt-VGqpC4jl-q2K792sVYP_rrlvMFA",
    authDomain: "toastmasters-daily.firebaseapp.com",
    projectId: "toastmasters-daily",
    storageBucket: "toastmasters-daily.firebasestorage.app",
    messagingSenderId: "864717492615",
    appId: "1:864717492615:web:155d3af4fb98a3fdab8322",
    measurementId: "G-HKP7YE09GD"
  },
  
  // Member project configuration
  member: {
    apiKey: "AIzaSyA7pa2o85IPlI6IuZ9xX8axY2jvYDSvfJY",
    authDomain: "toastmasters-daily-members.firebaseapp.com",
    projectId: "toastmasters-daily-members",
    storageBucket: "toastmasters-daily-members.firebasestorage.app",
    messagingSenderId: "839987965726",
    appId: "1:839987965726:web:d8941dab37f298f521e30f",
    measurementId: "G-4WDH1SSSE8"
  }
};

// Export for use in other scripts
if (typeof module !== 'undefined' && module.exports) {
  module.exports = FirebaseConfigs;
}

