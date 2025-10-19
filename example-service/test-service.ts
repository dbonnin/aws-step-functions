import axios from 'axios';

// Test configuration
const SERVICE_URL = 'http://localhost:3000';
const TEST_TIMEOUT = 10000; // 10 seconds

// Colors for console output
const colors = {
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  reset: '\x1b[0m',
  bold: '\x1b[1m'
};

// Test utilities
function log(message: string, color: string = colors.reset) {
  console.log(`${color}${message}${colors.reset}`);
}

function logSuccess(message: string) {
  log(`✅ ${message}`, colors.green);
}

function logError(message: string) {
  log(`❌ ${message}`, colors.red);
}

function logInfo(message: string) {
  log(`ℹ️  ${message}`, colors.blue);
}

function logWarning(message: string) {
  log(`⚠️  ${message}`, colors.yellow);
}

// Test data
const initialPayload = {
  userId: 123,
  action: "test-workflow",
  data: {
    testCase: "service-chaining",
    timestamp: new Date().toISOString()
  }
};

const service1Payload = {
  startDateTime: "2025-10-19T10:00:00.000Z",
  endDateTime: "",
  services_response: [
    {
      service_name: "service1",
      startDateTime: "2025-10-19T10:00:00.000Z",
      endDateTime: "2025-10-19T10:00:00.250Z",
      service_ip: "10.0.1.123",
      hostname: "mock-service1-host",
      processingTimeMs: 250,
      data: {
        message: "Data processed successfully by service1",
        receivedData: initialPayload
      }
    }
  ]
};

const service2Payload = {
  startDateTime: "2025-10-19T10:00:00.000Z",
  endDateTime: "",
  services_response: [
    {
      service_name: "service1",
      startDateTime: "2025-10-19T10:00:00.000Z",
      endDateTime: "2025-10-19T10:00:00.250Z",
      service_ip: "10.0.1.123",
      hostname: "mock-service1-host",
      processingTimeMs: 250,
      data: {
        message: "Data processed successfully by service1",
        receivedData: initialPayload
      }
    },
    {
      service_name: "service2",
      startDateTime: "2025-10-19T10:00:01.000Z",
      endDateTime: "2025-10-19T10:00:01.300Z",
      service_ip: "10.0.2.234",
      hostname: "mock-service2-host",
      processingTimeMs: 300,
      data: {
        message: "Data processed successfully by service2",
        receivedData: service1Payload
      }
    }
  ]
};

// Test functions
async function testHealthEndpoint(): Promise<boolean> {
  try {
    logInfo('Testing health endpoint...');
    const response = await axios.get(`${SERVICE_URL}/health`, {
      timeout: TEST_TIMEOUT
    });

    if (response.status === 200) {
      logSuccess('Health endpoint responding correctly');
      logInfo(`Service: ${response.data.service}`);
      logInfo(`Status: ${response.data.status}`);
      logInfo(`Hostname: ${response.data.hostname}`);
      return true;
    } else {
      logError(`Health endpoint returned status: ${response.status}`);
      return false;
    }
  } catch (error) {
    logError(`Health endpoint failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
    return false;
  }
}

async function testProcessEndpointAsFirstService(): Promise<any> {
  try {
    logInfo('Testing process endpoint as first service (like service1)...');
    const response = await axios.post(`${SERVICE_URL}/process`, initialPayload, {
      headers: { 'Content-Type': 'application/json' },
      timeout: TEST_TIMEOUT
    });

    if (response.status === 200) {
      logSuccess('First service call successful');
      
      // Validate response structure
      const data = response.data;
      
      if (!data.startDateTime) {
        logError('Missing startDateTime in response');
        return null;
      }
      
      if (!Array.isArray(data.services_response)) {
        logError('services_response is not an array');
        return null;
      }
      
      if (data.services_response.length !== 1) {
        logError(`Expected 1 service response, got ${data.services_response.length}`);
        return null;
      }
      
      const serviceResponse = data.services_response[0];
      if (!serviceResponse.service_name || !serviceResponse.startDateTime || 
          !serviceResponse.endDateTime || !serviceResponse.service_ip) {
        logError('Missing required fields in service response');
        return null;
      }
      
      logSuccess('Response structure is valid');
      logInfo(`Service name: ${serviceResponse.service_name}`);
      logInfo(`Processing time: ${serviceResponse.processingTimeMs}ms`);
      
      return data;
    } else {
      logError(`Process endpoint returned status: ${response.status}`);
      return null;
    }
  } catch (error) {
    logError(`Process endpoint failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
    return null;
  }
}

async function testProcessEndpointAsMiddleService(): Promise<any> {
  try {
    logInfo('Testing process endpoint as middle service (like service2)...');
    const response = await axios.post(`${SERVICE_URL}/process`, service1Payload, {
      headers: { 'Content-Type': 'application/json' },
      timeout: TEST_TIMEOUT
    });

    if (response.status === 200) {
      logSuccess('Middle service call successful');
      
      // Validate response structure
      const data = response.data;
      
      if (data.startDateTime !== service1Payload.startDateTime) {
        logError('startDateTime was not preserved from previous service');
        return null;
      }
      
      if (!Array.isArray(data.services_response) || data.services_response.length !== 2) {
        logError(`Expected 2 service responses, got ${data.services_response.length}`);
        return null;
      }
      
      // Check that previous service data is preserved
      const previousService = data.services_response[0];
      if (previousService.service_name !== 'service1') {
        logError('Previous service data was not preserved correctly');
        return null;
      }
      
      // Check that current service data is added
      const currentService = data.services_response[1];
      if (!currentService.service_name || !currentService.startDateTime || 
          !currentService.endDateTime || !currentService.service_ip) {
        logError('Current service data is incomplete');
        return null;
      }
      
      logSuccess('Middle service response structure is valid');
      logInfo(`Current service: ${currentService.service_name}`);
      logInfo(`Processing time: ${currentService.processingTimeMs}ms`);
      
      return data;
    } else {
      logError(`Process endpoint returned status: ${response.status}`);
      return null;
    }
  } catch (error) {
    logError(`Process endpoint failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
    return null;
  }
}

async function testProcessEndpointAsLastService(): Promise<any> {
  try {
    logInfo('Testing process endpoint as last service (like service3)...');
    const response = await axios.post(`${SERVICE_URL}/process`, service2Payload, {
      headers: { 'Content-Type': 'application/json' },
      timeout: TEST_TIMEOUT
    });

    if (response.status === 200) {
      logSuccess('Last service call successful');
      
      // Validate response structure
      const data = response.data;
      
      if (data.startDateTime !== service2Payload.startDateTime) {
        logError('startDateTime was not preserved through the chain');
        return null;
      }
      
      if (!Array.isArray(data.services_response) || data.services_response.length !== 3) {
        logError(`Expected 3 service responses, got ${data.services_response.length}`);
        return null;
      }
      
      // Check that all previous service data is preserved
      const services = data.services_response;
      const serviceNames = services.map(s => s.service_name);
      
      if (!serviceNames.includes('service1') || !serviceNames.includes('service2')) {
        logError('Previous services data was not preserved correctly');
        return null;
      }
      
      logSuccess('Complete workflow chain response is valid');
      logInfo(`Total services processed: ${services.length}`);
      
      // Calculate total processing time
      const totalProcessingTime = services.reduce((total, service) => total + service.processingTimeMs, 0);
      logInfo(`Total processing time: ${totalProcessingTime}ms`);
      
      return data;
    } else {
      logError(`Process endpoint returned status: ${response.status}`);
      return null;
    }
  } catch (error) {
    logError(`Process endpoint failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
    return null;
  }
}

async function testErrorHandling(): Promise<boolean> {
  try {
    logInfo('Testing error handling with invalid payload...');
    const response = await axios.post(`${SERVICE_URL}/process`, 'invalid-json', {
      headers: { 'Content-Type': 'application/json' },
      timeout: TEST_TIMEOUT
    });

    // Should not reach here with invalid JSON
    logWarning('Service accepted invalid JSON - this might be a problem');
    return false;
  } catch (error) {
    if (axios.isAxiosError(error) && error.response) {
      if (error.response.status >= 400) {
        logSuccess('Service correctly handles invalid requests');
        return true;
      }
    }
    logError(`Unexpected error handling test: ${error instanceof Error ? error.message : 'Unknown error'}`);
    return false;
  }
}

// Main test runner
async function runTests() {
  log(`${colors.bold}🧪 Starting Service Tests${colors.reset}`);
  log('==================================');
  
  let passed = 0;
  let failed = 0;
  
  // Test 1: Health endpoint
  if (await testHealthEndpoint()) {
    passed++;
  } else {
    failed++;
    logError('Cannot proceed without healthy service');
    return;
  }
  
  console.log('');
  
  // Test 2: First service call
  const firstServiceResult = await testProcessEndpointAsFirstService();
  if (firstServiceResult) {
    passed++;
    log(`${colors.yellow}First service response:${colors.reset}`);
    console.log(JSON.stringify(firstServiceResult, null, 2));
  } else {
    failed++;
  }
  
  console.log('');
  
  // Test 3: Middle service call
  const middleServiceResult = await testProcessEndpointAsMiddleService();
  if (middleServiceResult) {
    passed++;
    log(`${colors.yellow}Middle service response:${colors.reset}`);
    console.log(JSON.stringify(middleServiceResult, null, 2));
  } else {
    failed++;
  }
  
  console.log('');
  
  // Test 4: Last service call
  const lastServiceResult = await testProcessEndpointAsLastService();
  if (lastServiceResult) {
    passed++;
    log(`${colors.yellow}Final service response:${colors.reset}`);
    console.log(JSON.stringify(lastServiceResult, null, 2));
  } else {
    failed++;
  }
  
  console.log('');
  
  // Test 5: Error handling
  if (await testErrorHandling()) {
    passed++;
  } else {
    failed++;
  }
  
  // Results
  console.log('');
  log('==================================', colors.bold);
  log(`${colors.bold}📊 Test Results${colors.reset}`);
  logSuccess(`Passed: ${passed}`);
  if (failed > 0) {
    logError(`Failed: ${failed}`);
  }
  
  if (failed === 0) {
    logSuccess('🎉 All tests passed! Your service is ready for the Step Functions workflow.');
  } else {
    logError('❌ Some tests failed. Please check the service implementation.');
  }
}

// Check if service is running before starting tests
async function checkServiceAvailability() {
  try {
    await axios.get(`${SERVICE_URL}/health`, { timeout: 2000 });
    return true;
  } catch (error) {
    return false;
  }
}

// Main execution
async function main() {
  logInfo('Checking if service is available...');
  
  if (!(await checkServiceAvailability())) {
    logError(`Service is not running at ${SERVICE_URL}`);
    logInfo('Please start the service first:');
    logInfo('  cd example-service');
    logInfo('  npm install');
    logInfo('  npm run dev');
    process.exit(1);
  }
  
  await runTests();
}

// Run if this file is executed directly
if (require.main === module) {
  main().catch(error => {
    logError(`Test execution failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
    process.exit(1);
  });
}

export { runTests, testHealthEndpoint, testProcessEndpointAsFirstService };