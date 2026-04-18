import amqp from 'amqplib';

let connection = null;
let channel = null;

const RABBITMQ_URL = process.env.RABBITMQ_URL || 'amqp://guest:guest@localhost:5672';

// Exchange and queue names
export const EXCHANGES = {
  USERS: 'users_exchange',
  AUDITIONS: 'auditions_exchange',
  VIDEOS: 'videos_exchange',
  EVALUATIONS: 'evaluations_exchange',
  CALLBACKS: 'callbacks_exchange',
  NOTIFICATIONS: 'notifications_exchange',
  INVITATIONS: 'invitations_exchange'
};

export const QUEUES = {
  USER_EVENTS: 'notification_user_events_queue',
  AUDITION_EVENTS: 'notification_audition_events_queue',
  EVALUATION_EVENTS: 'notification_evaluation_events_queue',
  INVITATION_EVENTS: 'notification_invitation_events_queue'
};

export const ROUTING_KEYS = {
  USER_CREATED: 'user.created',
  USER_DELETED: 'user.deleted',
  AUDITION_REVIEWED: 'audition.reviewed',
  EVALUATION_COMPLETED: 'evaluation.completed',
  INVITATION_CREATED: 'invitation.created',
  INVITATION_UPDATED: 'invitation.updated',
};

/**
 * Connect to RabbitMQ
 */
export const connectRabbitMQ = async () => {
  try {
    if (connection) {
      console.log('RabbitMQ already connected');
      return channel;
    }

    connection = await amqp.connect(RABBITMQ_URL);
    channel = await connection.createChannel();

    // Handle connection errors
    connection.on('error', (err) => {
      console.error('RabbitMQ connection error:', err);
      connection = null;
      channel = null;
    });

    connection.on('close', () => {
      console.log('RabbitMQ connection closed');
      connection = null;
      channel = null;
    });

    console.log('Connected to RabbitMQ');
    return channel;
  } catch (error) {
    console.error('Failed to connect to RabbitMQ:', error);
    throw error;
  }
};

/**
 * Get or create channel
 */
export const getChannel = async () => {
  if (!channel) {
    await connectRabbitMQ();
  }
  return channel;
};

/**
 * Assert an exchange
 */
export const assertExchange = async (exchangeName, type = 'topic') => {
  try {
    const ch = await getChannel();
    await ch.assertExchange(exchangeName, type, { durable: true });
  } catch (error) {
    console.error(`Failed to assert exchange ${exchangeName}:`, error);
    throw error;
  }
};

/**
 * Assert a queue
 */
export const assertQueue = async (queueName) => {
  try {
    const ch = await getChannel();
    await ch.assertQueue(queueName, { durable: true });
  } catch (error) {
    console.error(`Failed to assert queue ${queueName}:`, error);
    throw error;
  }
};

/**
 * Bind queue to exchange
 */
export const bindQueue = async (queueName, exchangeName, routingKey) => {
  try {
    const ch = await getChannel();
    await ch.bindQueue(queueName, exchangeName, routingKey);
  } catch (error) {
    console.error(`Failed to bind queue ${queueName} to exchange ${exchangeName}:`, error);
    throw error;
  }
};

/**
 * Publish message to exchange
 */
export const publishMessage = async (exchangeName, routingKey, message) => {
  try {
    const ch = await getChannel();
    await assertExchange(exchangeName);
    
    const messageBuffer = Buffer.from(JSON.stringify(message));
    ch.publish(exchangeName, routingKey, messageBuffer, { persistent: true });
    
    console.log(`Message published to ${exchangeName} with routing key ${routingKey}`);
  } catch (error) {
    console.error('Failed to publish message:', error);
    throw error;
  }
};

/**
 * Consume messages from queue
 */
export const consumeMessages = async (queueName, callback) => {
  try {
    const ch = await getChannel();
    await assertQueue(queueName);
    
    await ch.consume(queueName, async (msg) => {
      if (msg) {
        try {
          const content = JSON.parse(msg.content.toString());
          await callback(msg.fields.routingKey, content);
          ch.ack(msg);
        } catch (error) {
          console.error('Error processing message:', error);
          // Reject and requeue
          ch.nack(msg, false, true);
        }
      }
    });
    
    console.log(`Started consuming messages from ${queueName}`);
  } catch (error) {
    console.error(`Failed to consume messages from ${queueName}:`, error);
    throw error;
  }
};

/**
 * Close RabbitMQ connection
 */
export const closeRabbitMQ = async () => {
  try {
    if (channel) {
      await channel.close();
    }
    if (connection) {
      await connection.close();
    }
    console.log('RabbitMQ connection closed');
  } catch (error) {
    console.error('Error closing RabbitMQ connection:', error);
  }
};
