// WebSocket handler for real-time presence
export default async function presenceWebSocket(fastify) {
  fastify.get('/ws/presence', { websocket: true }, (connection, req) => {
    const userId = req.query.userId;
    
    if (!userId) {
      connection.socket.close(4001, 'userId required');
      return;
    }

    // Register connection
    connection.socket.on('message', async (message) => {
      try {
        const data = JSON.parse(message.toString());

        switch (data.type) {
          case 'location_update':
            // Broadcast location to nearby users
            // In production, use Redis pub/sub for horizontal scaling
            connection.socket.send(JSON.stringify({
              type: 'ack',
              subtype: 'location_update',
              timestamp: new Date().toISOString()
            }));
            break;

          case 'ping':
            connection.socket.send(JSON.stringify({
              type: 'pong',
              timestamp: new Date().toISOString()
            }));
            break;

          default:
            connection.socket.send(JSON.stringify({
              type: 'error',
              message: 'Unknown message type'
            }));
        }
      } catch (err) {
        connection.socket.send(JSON.stringify({
          type: 'error',
          message: 'Invalid JSON'
        }));
      }
    });

    connection.socket.on('close', () => {
      // Clean up connection
      fastify.log.info(`WebSocket connection closed for user ${userId}`);
    });

    // Send welcome
    connection.socket.send(JSON.stringify({
      type: 'connected',
      userId,
      timestamp: new Date().toISOString()
    }));
  });
}