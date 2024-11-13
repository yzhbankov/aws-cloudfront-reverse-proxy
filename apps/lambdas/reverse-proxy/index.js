'use strict';
const versionMapping = require('./version_mapping.json');

exports.handler = (event, context, callback) => {
    const request = event.Records[0].cf.request;
    const releaseVersion = Array.isArray(request.headers['x-release-version']) ? request.headers['x-release-version'][0].value : 'v1';

    let domainName = versionMapping[releaseVersion] || '';

    console.log('domainName: ', domainName);

    /* Set custom origin fields*/
    request.origin = {
        custom: {
            domainName: domainName,
            port: 80,
            protocol: 'http',
            path: '',
            sslProtocols: ['TLSv1.2'], // Only use TLSv1.2 or higher
            readTimeout: 5,
            keepaliveTimeout: 5,
            customHeaders: {}
        }
    };
    request.headers['host'] = [{ key: 'host', value: domainName}];

    callback(null, request);
};
