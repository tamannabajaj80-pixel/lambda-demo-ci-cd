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
  
  // Handle Direct HTTP Requests (Functional URL)
  return {
    statusCode: 200,
    body: "yeeeh finaaly functioanl url created Lambda automated deployment completed!"
  };
};