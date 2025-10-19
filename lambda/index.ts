import { SFNClient, StartExecutionCommand } from '@aws-sdk/client-sfn';
import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';

const sfnClient = new SFNClient({ region: process.env.AWS_REGION || 'us-east-1' });

interface WorkflowInput {
  [key: string]: any;
}

interface LambdaResponse {
  statusCode: number;
  body: string;
  headers: {
    'Content-Type': string;
    'Access-Control-Allow-Origin': string;
  };
}

export const handler = async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
  console.log('Event received:', JSON.stringify(event, null, 2));

  try {
    // Parse input from the event
    let input: WorkflowInput = {};
    
    if (event.body) {
      try {
        input = JSON.parse(event.body);
      } catch (error) {
        console.error('Error parsing request body:', error);
        return createResponse(400, {
          error: 'Invalid JSON in request body',
          message: error instanceof Error ? error.message : 'Unknown error'
        });
      }
    }

    // Get the state machine ARN from environment variables
    const stateMachineArn = process.env.STATE_MACHINE_ARN;
    
    if (!stateMachineArn) {
      console.error('STATE_MACHINE_ARN environment variable is not set');
      return createResponse(500, {
        error: 'Configuration error',
        message: 'STATE_MACHINE_ARN is not configured'
      });
    }

    // Generate a unique execution name
    const executionName = `execution-${Date.now()}-${Math.random().toString(36).substring(7)}`;

    // Start the Step Functions execution
    const command = new StartExecutionCommand({
      stateMachineArn,
      name: executionName,
      input: JSON.stringify(input)
    });

    console.log('Starting Step Functions execution:', {
      stateMachineArn,
      executionName,
      input
    });

    const response = await sfnClient.send(command);

    console.log('Step Functions execution started:', response);

    // Return success response
    return createResponse(200, {
      message: 'Workflow execution started successfully',
      executionArn: response.executionArn,
      executionName,
      startDate: response.startDate
    });

  } catch (error) {
    console.error('Error starting workflow execution:', error);
    
    return createResponse(500, {
      error: 'Failed to start workflow execution',
      message: error instanceof Error ? error.message : 'Unknown error',
      stack: error instanceof Error ? error.stack : undefined
    });
  }
};

function createResponse(statusCode: number, body: any): LambdaResponse {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*'
    },
    body: JSON.stringify(body, null, 2)
  };
}