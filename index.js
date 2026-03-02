exports.handler = async (event) => {
  console.log('Event received:', JSON.stringify(event, null, 2));
  
  // Simple HTTP response for Functional URL
  return {
    statusCode: 200,
    body: "yeeeh finaaly functioanl url created Lambda automated deployment completed!"
  };
};