const express = require('express');
const cors = require('cors');
const os = require('os');
const fs = require('fs');
const { execSync } = require('child_process');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Variables globales
let requestCount = 0;
const startTime = new Date();

// Middleware de logging
app.use((req, res, next) => {
    requestCount++;
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] ${req.method} ${req.path} - Request #${requestCount}`);
    next();
});

// Utilitaires
function getSystemInfo() {
    const hostname = os.hostname();
    const networkInterfaces = os.networkInterfaces();
    let ip = 'unknown';
    
    // Trouver l'IP principale (non loopback)
    for (const interfaceName in networkInterfaces) {
        const addresses = networkInterfaces[interfaceName];
        for (const addr of addresses) {
            if (addr.family === 'IPv4' && !addr.internal) {
                ip = addr.address;
                break;
            }
        }
        if (ip !== 'unknown') break;
    }
    
    return {
        hostname,
        ip,
        platform: os.platform(),
        architecture: os.arch(),
        nodeVersion: process.version,
        uptime: process.uptime(),
        memory: process.memoryUsage(),
        cpuCount: os.cpus().length,
        loadAverage: os.loadavg(),
        service: process.env.SERVICE_NAME || 'api',
        version: process.env.SERVICE_VERSION || '1.0.0'
    };
}

function getDockerInfo() {
    try {
        // Informations sur le conteneur actuel
        const containerId = execSync('hostname', { encoding: 'utf8' }).trim();
        
        let dockerInfo = {
            containerId,
            isDocker: fs.existsSync('/.dockerenv')
        };
        
        // Essayer de récupérer plus d'infos Docker si possible
        try {
            const dockerPs = execSync('docker ps --format "table {{.Names}}\\t{{.Status}}"', { encoding: 'utf8' });
            dockerInfo.containers = dockerPs;
        } catch (e) {
            dockerInfo.containers = 'Accès Docker non disponible';
        }
        
        return dockerInfo;
    } catch (error) {
        return { error: error.message };
    }
}

// Routes API
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        service: 'api',
        version: '1.0.0',
        requestCount
    });
});

app.get('/info', (req, res) => {
    const systemInfo = getSystemInfo();
    const dockerInfo = getDockerInfo();
    
    res.json({
        ...systemInfo,
        docker: dockerInfo,
        stats: {
            requestCount,
            startTime: startTime.toISOString(),
            currentTime: new Date().toISOString()
        }
    });
});

app.get('/nodes', (req, res) => {
    try {
        // Simuler les informations des nœuds Swarm
        // En production, ceci utiliserait l'API Docker
        const nodes = [
            {
                id: 'manager-1',
                hostname: 'manager-node',
                role: 'manager',
                status: 'Ready',
                availability: 'Active',
                ip: '192.168.1.10'
            },
            {
                id: 'worker-1', 
                hostname: 'worker-node',
                role: 'worker',
                status: 'Ready',
                availability: 'Active',
                ip: '192.168.1.11'
            }
        ];
        
        res.json({
            nodes,
            totalNodes: nodes.length,
            managersCount: nodes.filter(n => n.role === 'manager').length,
            workersCount: nodes.filter(n => n.role === 'worker').length
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.get('/services', (req, res) => {
    try {
        // Simuler les informations des services
        const services = [
            {
                id: 'web-app',
                name: 'web-stack_web-app',
                mode: 'replicated',
                replicas: '3/3',
                image: 'web-app:latest',
                ports: ['80:80']
            },
            {
                id: 'api',
                name: 'web-stack_api',
                mode: 'replicated',
                replicas: '2/2', 
                image: 'api:latest',
                ports: ['3000:3000']
            }
        ];
        
        res.json(services);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.get('/stats', (req, res) => {
    const stats = {
        requestCount,
        startTime: startTime.toISOString(),
        uptime: process.uptime(),
        memory: process.memoryUsage(),
        cpu: os.loadavg(),
        platform: {
            os: os.platform(),
            arch: os.arch(),
            node: process.version
        },
        environment: {
            NODE_ENV: process.env.NODE_ENV || 'development',
            PORT: PORT,
            SERVICE_NAME: process.env.SERVICE_NAME || 'api',
            SERVICE_VERSION: process.env.SERVICE_VERSION || '1.0.0'
        }
    };
    
    res.json(stats);
});

// Route de test de charge
app.post('/load-test', (req, res) => {
    const { iterations = 100 } = req.body;
    
    console.log(`Starting load test with ${iterations} iterations`);
    
    // Simuler une charge CPU
    const start = Date.now();
    for (let i = 0; i < iterations; i++) {
        Math.sqrt(Math.random() * 1000000);
    }
    const duration = Date.now() - start;
    
    res.json({
        message: 'Load test completed',
        iterations,
        duration: `${duration}ms`,
        requestCount,
        timestamp: new Date().toISOString()
    });
});

// Route pour les métriques Prometheus (optionnel)
app.get('/metrics', (req, res) => {
    const metrics = `
# HELP api_requests_total Total number of API requests
# TYPE api_requests_total counter
api_requests_total ${requestCount}

# HELP api_uptime_seconds API uptime in seconds
# TYPE api_uptime_seconds gauge
api_uptime_seconds ${Math.floor(process.uptime())}

# HELP api_memory_usage_bytes Memory usage in bytes
# TYPE api_memory_usage_bytes gauge
api_memory_usage_bytes ${process.memoryUsage().rss}
    `.trim();
    
    res.set('Content-Type', 'text/plain');
    res.send(metrics);
});

// Route catch-all pour les erreurs 404
app.use('*', (req, res) => {
    res.status(404).json({
        error: 'Route not found',
        path: req.originalUrl,
        method: req.method,
        timestamp: new Date().toISOString()
    });
});

// Gestion des erreurs globales
app.use((error, req, res, next) => {
    console.error('Error:', error);
    res.status(500).json({
        error: 'Internal server error',
        message: error.message,
        timestamp: new Date().toISOString()
    });
});

// Démarrage du serveur
app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 API Server started on port ${PORT}`);
    console.log(`📊 Health check: http://localhost:${PORT}/health`);
    console.log(`📋 System info: http://localhost:${PORT}/info`);
    console.log(`🐳 Docker nodes: http://localhost:${PORT}/nodes`);
    console.log(`📈 Metrics: http://localhost:${PORT}/metrics`);
    console.log(`---`);
    console.log(`System Info:`, getSystemInfo());
});

// Gestion gracieuse de l'arrêt
process.on('SIGTERM', () => {
    console.log('SIGTERM received, shutting down gracefully');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('SIGINT received, shutting down gracefully');
    process.exit(0);
});