const axios = require('axios');

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
function log(message, color = colors.reset) {
  console.log(`${color}${message}${colors.reset}`);
}

function logSuccess(message) {
  log(`✅ ${message}`, colors.green);
}

function logError(message) {
  log(`❌ ${message}`, colors.red);
}

function logInfo(message) {
  log(`ℹ️  ${message}`, colors.blue);
}

function logWarning(message) {
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

// Test functions
async function testHealthEndpoint() {
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
    logError(`Health endpoint failed: ${error.message}`);
    return false;
  }
}

async function testProcessEndpointAsFirstService() {
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
    logError(`Process endpoint failed: ${error.message}`);
    return null;
  }
}

async function testProcessEndpointAsMiddleService() {
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
    logError(`Process endpoint failed: ${error.message}`);
    return null;
  }
}

async function testSimulateFullWorkflow() {
  try {
    logInfo('🔄 Simulating full workflow (service1 -> service2 -> service3)...');
    
    // Call as service1 (first service)
    logInfo('Step 1: Calling as service1...');
    const service1Response = await axios.post(`${SERVICE_URL}/process`, initialPayload, {
      headers: { 'Content-Type': 'application/json' },
      timeout: TEST_TIMEOUT
    });
    
    if (service1Response.status !== 200) {
      logError('Service1 call failed');
      return null;
    }
    
    // Call as service2 (middle service)
    logInfo('Step 2: Calling as service2...');
    const service2Response = await axios.post(`${SERVICE_URL}/process`, service1Response.data, {
      headers: { 'Content-Type': 'application/json' },
      timeout: TEST_TIMEOUT
    });
    
    if (service2Response.status !== 200) {
      logError('Service2 call failed');
      return null;
    }
    
    // Call as service3 (final service)
    logInfo('Step 3: Calling as service3...');
    const service3Response = await axios.post(`${SERVICE_URL}/process`, service2Response.data, {
      headers: { 'Content-Type': 'application/json' },
      timeout: TEST_TIMEOUT
    });
    
    if (service3Response.status !== 200) {
      logError('Service3 call failed');
      return null;
    }
    
    const finalPayload = service3Response.data;
    
    // Validate final payload
    if (!finalPayload.startDateTime || !Array.isArray(finalPayload.services_response)) {
      logError('Invalid final payload structure');
      return null;
    }
    
    if (finalPayload.services_response.length !== 3) {
      logError(`Expected 3 services in final payload, got ${finalPayload.services_response.length}`);
      return null;
    }
    
    logSuccess('🎉 Full workflow simulation completed successfully!');
    
    // Show summary
    const services = finalPayload.services_response;
    const totalProcessingTime = services.reduce((total, service) => total + service.processingTimeMs, 0);
    
    logInfo('=== WORKFLOW SUMMARY ===');
    logInfo(`Workflow started: ${finalPayload.startDateTime}`);
    logInfo(`Services processed: ${services.length}`);
    logInfo(`Total processing time: ${totalProcessingTime}ms`);
    
    services.forEach((service, index) => {
      logInfo(`${index + 1}. ${service.service_name} (${service.processingTimeMs}ms) - ${service.service_ip}`);
    });
    
    return finalPayload;
    
  } catch (error) {
    logError(`Full workflow simulation failed: ${error.message}`);
    return null;
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
    log(`${colors.yellow}First service response sample:${colors.reset}`);
    console.log(JSON.stringify({
      startDateTime: firstServiceResult.startDateTime,
      services_response: [{
        service_name: firstServiceResult.services_response[0].service_name,
        processingTimeMs: firstServiceResult.services_response[0].processingTimeMs,
        service_ip: firstServiceResult.services_response[0].service_ip
      }]
    }, null, 2));
  } else {
    failed++;
  }
  
  console.log('');
  
  // Test 3: Middle service call
  const middleServiceResult = await testProcessEndpointAsMiddleService();
  if (middleServiceResult) {
    passed++;
  } else {
    failed++;
  }
  
  console.log('');
  
  // Test 4: Full workflow simulation
  const workflowResult = await testSimulateFullWorkflow();
  if (workflowResult) {
    passed++;
    log(`${colors.yellow}Final workflow payload structure:${colors.reset}`);
    console.log(JSON.stringify({
      startDateTime: workflowResult.startDateTime,
      endDateTime: workflowResult.endDateTime,
      services_response: workflowResult.services_response.map(s => ({
        service_name: s.service_name,
        startDateTime: s.startDateTime,
        endDateTime: s.endDateTime,
        service_ip: s.service_ip,
        processingTimeMs: s.processingTimeMs
      }))
    }, null, 2));
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
    logInfo('');
    logInfo('Next steps:');
    logInfo('1. Build and push your Docker image');
    logInfo('2. Configure terraform.tfvars with your image URL');
    logInfo('3. Deploy with: make all');
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
    logInfo('');
    logInfo('Please start the service first:');
    logInfo('  cd example-service');
    logInfo('  npm install');
    logInfo('  SERVICE_NAME=service1 npm run dev');
    logInfo('');
    logInfo('In another terminal, run this test:');
    logInfo('  npm test');
    process.exit(1);
  }
  
  await runTests();
}

// Run if this file is executed directly
if (require.main === module) {
  main().catch(error => {
    logError(`Test execution failed: ${error.message}`);
    process.exit(1);
  });
}