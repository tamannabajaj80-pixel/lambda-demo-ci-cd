const { handler } = require('./index.js');

handler().then(result => {
  console.log('Lambda Response:', result);
}).catch(error => {
  console.error('Error:', error);
});
