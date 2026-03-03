exports.handler = async (event) => {
  console.log('Event received:', JSON.stringify(event, null, 2));
  
  // Handle SQS Messages
  if (event.Records && event.Records.length > 0) {
    const messages = event.Records.map(record => {
      const messageBody = JSON.parse(record.body);
      return {
        messageId: record.messageId,
        body: messageBody,
        timestamp: record.attributes.ApproximateFirstReceiveTimestamp
      };
    });
    
    console.log(`Processing ${messages.length} SQS messages:`, messages);
    
    return {
      statusCode: 200,
      body: JSON.stringify({
        message: "yeeeh SQS messages processed successfully!",
        processedMessages: messages.length,
        messages: messages
      })
    };
  }
  
  // Handle API Gateway requests - check if it's an array or single message
  let requestBody;
  
  if (typeof event.body === 'string') {
    try {
      requestBody = JSON.parse(event.body);
    } catch (e) {
      requestBody = event.body;
    }
  } else {
    requestBody = event.body;
  }
  
  // Check if it's an array of messages
  if (Array.isArray(requestBody)) {
    console.log(`Processing array of ${requestBody.length} messages:`, requestBody);
    
    return {
      statusCode: 200,
      body: JSON.stringify({
        message: `yeeeh Successfully processed ${requestBody.length} messages!`,
        type: "array_processing",
        count: requestBody.length,
        messages: requestBody
      })
    };
  }
  
  // Handle single message (API Gateway or direct Lambda)
  console.log('Processing single message:', requestBody);
  
  return {
    statusCode: 200,
    body: JSON.stringify({
      message: "yeeeh finaaly functioanl url created Lambda automated deployment completed!",
      type: "single_message",
      received: requestBody
    })
  };
};