const https = require('https');
const http = require('http');

exports.handler = async (event) => {
    console.log('Lambda received event:', JSON.stringify(event, null, 2));
    
    const serviceEndpoint = process.env.SERVICE_ENDPOINT;
    const serviceName = process.env.SERVICE_NAME;
    
    if (!serviceEndpoint) {
        throw new Error('SERVICE_ENDPOINT environment variable is required');
    }
    
    const url = new URL(`${serviceEndpoint}/process`);
    const client = url.protocol === 'https:' ? https : http;
    
    const postData = JSON.stringify(event);
    
    const options = {
        hostname: url.hostname,
        port: url.port || (url.protocol === 'https:' ? 443 : 80),
        path: url.pathname,
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(postData)
        }
    };
    
    return new Promise((resolve, reject) => {
        const req = client.request(options, (res) => {
            let data = '';
            
            res.on('data', (chunk) => {
                data += chunk;
            });
            
            res.on('end', () => {
                try {
                    const response = JSON.parse(data);
                    console.log(`${serviceName} response:`, response);
                    resolve(response);
                } catch (error) {
                    console.error('Error parsing response:', error);
                    reject(new Error(`Failed to parse response from ${serviceName}`));
                }
            });
        });
        
        req.on('error', (error) => {
            console.error(`Error calling ${serviceName}:`, error);
            reject(error);
        });
        
        req.write(postData);
        req.end();
    });
};