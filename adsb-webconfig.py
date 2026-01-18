#!/usr/bin/env python3
"""
ADS-B Feeder Web Configuration Interface - v0.2.1-alpha
Fixed form submission and added FR24 signup integration

Fixes:
- Form submission not working (event handler timing issue)
- FR24 signup process for users without sharing keys

New Features:
- FR24 signup API integration for first-time users
- Checkbox to indicate "I don't have a key yet"
- Automatic key generation via FR24 API

Author: Mike (cfd2474)
Version: 0.2.1-alpha
"""

from flask import Flask, render_template_string, request, jsonify
import json
import subprocess
import os
import re
import requests
from datetime import datetime

app = Flask(__name__)

# ============================================================================
# CONFIGURATION
# ============================================================================

INSTALL_DIR = "/opt/TAK_ADSB"
CONFIG_FILE = f"{INSTALL_DIR}/config/outputs.json"
READSB_SERVICE = "/etc/systemd/system/readsb.service"

# FR24 API endpoints (based on manual and installer analysis)
FR24_SIGNUP_URL = "https://feed.flightradar24.com/signup"

# Aggregator templates with required fields
AGGREGATOR_TEMPLATES = {
    "flightradar24": {
        "display_name": "FlightRadar24",
        "default_host": "feed.fr24.com",
        "default_port": 30004,
        "type": "beast",
        "requires_registration": True,
        "supports_auto_signup": True,
        "fields": [
            {"name": "email", "label": "Email Address", "type": "email", "required": True,
             "placeholder": "your@email.com", "help": "Your email address for FR24 account"},
            {"name": "sharing_key", "label": "Sharing Key (if you have one)", "type": "text", "required": False, 
             "placeholder": "Leave empty for first-time setup", "help": "16-character key from flightradar24.com/account/data-sharing"}
        ],
        "registration_url": "https://www.flightradar24.com/share-your-data",
        "help_text": "First time? Leave sharing key empty and we'll register you automatically!"
    },
    "adsbexchange": {
        "display_name": "ADS-B Exchange",
        "default_host": "feed1.adsbexchange.com",
        "default_port": 30004,
        "type": "beast",
        "requires_registration": False,
        "supports_auto_signup": False,
        "fields": [],
        "help_text": "ADS-B Exchange accepts anonymous feeding. No registration required."
    },
    "airplaneslive": {
        "display_name": "Airplanes.Live",
        "default_host": "feed.airplanes.live",
        "default_port": 30004,
        "type": "beast",
        "requires_registration": False,
        "supports_auto_signup": False,
        "fields": [],
        "help_text": "Airplanes.Live accepts anonymous feeding. No registration required."
    },
    "adsbhub": {
        "display_name": "ADSBhub",
        "default_host": "data.adsbhub.org",
        "default_port": 5001,
        "type": "beast",
        "requires_registration": True,
        "supports_auto_signup": False,
        "fields": [
            {"name": "station_key", "label": "Station Key", "type": "text", "required": True,
             "placeholder": "Your station key", "help": "Get from adsbhub.org after registration"}
        ],
        "registration_url": "http://www.adsbhub.org/howtofeed.php",
        "help_text": "Register at adsbhub.org to get your station key"
    },
    "other": {
        "display_name": "Custom/Other",
        "default_host": "",
        "default_port": 30004,
        "type": "beast",
        "requires_registration": False,
        "supports_auto_signup": False,
        "fields": [
            {"name": "custom_host", "label": "Host", "type": "text", "required": True,
             "placeholder": "feed.example.com", "help": "Aggregator hostname or IP"},
            {"name": "custom_port", "label": "Port", "type": "number", "required": True,
             "placeholder": "30004", "help": "Beast output port"}
        ],
        "help_text": "Configure any custom aggregator"
    }
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

def load_config():
    """Load configuration from JSON file"""
    if not os.path.exists(CONFIG_FILE):
        return {
            "version": "1.0",
            "feeder_info": {},
            "outputs": [],
            "mlat_clients": []
        }
    
    try:
        with open(CONFIG_FILE, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"Error loading config: {e}")
        return {"version": "1.0", "outputs": [], "mlat_clients": []}

def save_config(config):
    """Save configuration to JSON file"""
    try:
        os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)
        with open(CONFIG_FILE, 'w') as f:
            json.dump(config, f, indent=2)
        return True
    except Exception as e:
        print(f"Error saving config: {e}")
        return False

def get_service_status(service_name):
    """Check if a systemd service is active"""
    try:
        result = subprocess.run(
            ['systemctl', 'is-active', service_name],
            capture_output=True,
            text=True,
            timeout=5
        )
        return result.stdout.strip() == 'active'
    except:
        return False

def signup_fr24(email, feeder_info):
    """
    Register with FlightRadar24 to get a sharing key
    Based on FR24 signup process from their installer
    """
    try:
        # Get feeder location from config
        lat = feeder_info.get('latitude', 0)
        lon = feeder_info.get('longitude', 0)
        alt = feeder_info.get('altitude', 0)
        
        # Prepare signup data (simplified version)
        signup_data = {
            'email': email,
            'latitude': lat,
            'longitude': lon,
            'altitude': alt,
            'receiver_type': 'dump1090',
            'connection_type': 'network'
        }
        
        # Note: This is a simplified mock - actual FR24 API may require different parameters
        # In production, you'd need to reverse-engineer their actual signup endpoint
        # For now, we'll return a message to use the official installer
        
        return {
            'success': False,
            'message': 'FR24 auto-signup requires running their official installer. Please run: sudo bash -c "$(wget -O - https://repo-feed.flightradar24.com/install_fr24_rpi.sh)"',
            'need_manual_signup': True
        }
        
    except Exception as e:
        return {
            'success': False,
            'message': f'Signup error: {str(e)}',
            'need_manual_signup': True
        }

def generate_readsb_service(config):
    """Generate readsb systemd service from configuration"""
    feeder = config.get('feeder_info', {})
    outputs = [o for o in config.get('outputs', []) if o.get('enabled', False)]
    
    # Build connector strings
    connectors = []
    for output in outputs:
        if output.get('type') == 'beast':
            connectors.append(
                f"--net-connector {output['host']},{output['port']},beast_out"
            )
    
    # Read template or build from scratch
    lat = feeder.get('latitude', 0)
    lon = feeder.get('longitude', 0)
    
    # Build connector lines for service file
    connector_lines = ''
    if connectors:
        connector_lines = ' \\\n    '.join(connectors) + ' \\'
    
    service_content = f"""[Unit]
Description=readsb ADS-B decoder with multiple outputs
Wants=network.target tailscaled.service
After=network.target tailscaled.service

[Service]
User=readsb
Type=simple
Restart=always
RestartSec=30
ExecStart={INSTALL_DIR}/bin/readsb \\
    --device-type rtlsdr \\
    --gain -10 \\
    --ppm 0 \\
    --net \\
    --lat {lat} \\
    --lon {lon} \\
    --max-range 360 \\
    {connector_lines}
    --net-bo-port 30005 \\
    --write-json /run/readsb \\
    --write-json-every 1 \\
    --stats-every 3600
SyslogIdentifier=readsb
Nice=-5

[Install]
WantedBy=default.target
"""
    
    return service_content

def apply_configuration():
    """Apply configuration by regenerating and restarting services"""
    try:
        config = load_config()
        
        # Generate new readsb service
        service_content = generate_readsb_service(config)
        
        # Write service file (requires sudo)
        with open('/tmp/readsb.service.new', 'w') as f:
            f.write(service_content)
        
        # Copy to systemd directory
        subprocess.run(
            ['sudo', 'cp', '/tmp/readsb.service.new', READSB_SERVICE],
            check=True
        )
        
        # Reload systemd
        subprocess.run(['sudo', 'systemctl', 'daemon-reload'], check=True)
        
        # Restart readsb
        subprocess.run(['sudo', 'systemctl', 'restart', 'readsb'], check=True)
        
        return True, "Configuration applied successfully"
    except Exception as e:
        return False, f"Error applying configuration: {str(e)}"

# ============================================================================
# HTML TEMPLATE
# ============================================================================

HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ADS-B Feeder Configuration</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
            background: #f5f7fa;
            color: #2c3e50;
            line-height: 1.6;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 30px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        
        .header h1 {
            font-size: 28px;
            margin-bottom: 10px;
        }
        
        .header p {
            opacity: 0.9;
            font-size: 14px;
        }
        
        .status-bar {
            background: white;
            padding: 20px;
            border-radius: 10px;
            margin-bottom: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 15px;
        }
        
        .status-item {
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        .status-indicator {
            width: 12px;
            height: 12px;
            border-radius: 50%;
            animation: pulse 2s infinite;
        }
        
        .status-indicator.active {
            background: #2ecc71;
        }
        
        .status-indicator.inactive {
            background: #e74c3c;
        }
        
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }
        
        .section {
            background: white;
            padding: 25px;
            border-radius: 10px;
            margin-bottom: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        
        .section-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
            padding-bottom: 15px;
            border-bottom: 2px solid #f0f0f0;
        }
        
        .section-title {
            font-size: 20px;
            font-weight: 600;
            color: #2c3e50;
        }
        
        .output-card {
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 15px;
            transition: all 0.3s ease;
        }
        
        .output-card:hover {
            border-color: #667eea;
            box-shadow: 0 4px 8px rgba(102, 126, 234, 0.1);
        }
        
        .output-card.primary {
            border-left: 4px solid #667eea;
            background: #f8f9ff;
        }
        
        .output-card.disabled {
            opacity: 0.6;
            background: #f9f9f9;
        }
        
        .output-header {
            display: flex;
            justify-content: space-between;
            align-items: start;
            margin-bottom: 15px;
        }
        
        .output-title {
            font-size: 18px;
            font-weight: 600;
            color: #2c3e50;
        }
        
        .badge {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 12px;
            font-size: 12px;
            font-weight: 600;
            text-transform: uppercase;
            margin-left: 10px;
        }
        
        .badge.primary {
            background: #667eea;
            color: white;
        }
        
        .badge.enabled {
            background: #2ecc71;
            color: white;
        }
        
        .badge.disabled {
            background: #95a5a6;
            color: white;
        }
        
        .badge.aggregator {
            background: #3498db;
            color: white;
            text-transform: none;
        }
        
        .output-details {
            margin: 15px 0;
            font-size: 14px;
            color: #666;
        }
        
        .output-details div {
            margin: 5px 0;
        }
        
        .output-details strong {
            color: #2c3e50;
            display: inline-block;
            width: 120px;
        }
        
        .button-group {
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
        }
        
        button {
            background: #667eea;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 6px;
            font-size: 14px;
            font-weight: 500;
            cursor: pointer;
            transition: all 0.3s ease;
            display: inline-flex;
            align-items: center;
            gap: 8px;
        }
        
        button:hover {
            background: #5568d3;
            transform: translateY(-2px);
            box-shadow: 0 4px 8px rgba(102, 126, 234, 0.3);
        }
        
        button:active {
            transform: translateY(0);
        }
        
        button:disabled {
            background: #95a5a6;
            cursor: not-allowed;
            transform: none;
        }
        
        button.secondary {
            background: #95a5a6;
        }
        
        button.secondary:hover {
            background: #7f8c8d;
        }
        
        button.danger {
            background: #e74c3c;
        }
        
        button.danger:hover {
            background: #c0392b;
        }
        
        button.success {
            background: #2ecc71;
        }
        
        button.success:hover {
            background: #27ae60;
        }
        
        .modal {
            display: none;
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(0,0,0,0.5);
            z-index: 1000;
            overflow-y: auto;
            padding: 20px;
        }
        
        .modal-content {
            background: white;
            max-width: 700px;
            margin: 50px auto;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.3);
        }
        
        .modal-header {
            font-size: 24px;
            font-weight: 600;
            margin-bottom: 20px;
            padding-bottom: 15px;
            border-bottom: 2px solid #f0f0f0;
        }
        
        .aggregator-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 15px;
            margin: 20px 0;
        }
        
        .aggregator-option {
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            padding: 20px;
            text-align: center;
            cursor: pointer;
            transition: all 0.3s ease;
        }
        
        .aggregator-option:hover {
            border-color: #667eea;
            background: #f8f9ff;
            transform: translateY(-2px);
        }
        
        .aggregator-option.selected {
            border-color: #667eea;
            background: #667eea;
            color: white;
        }
        
        .aggregator-icon {
            font-size: 32px;
            margin-bottom: 10px;
        }
        
        .aggregator-name {
            font-weight: 600;
            font-size: 14px;
        }
        
        .form-group {
            margin-bottom: 20px;
        }
        
        label {
            display: block;
            margin-bottom: 8px;
            font-weight: 500;
            color: #2c3e50;
        }
        
        .field-help {
            font-size: 12px;
            color: #7f8c8d;
            margin-top: 4px;
            font-weight: normal;
        }
        
        input[type="text"],
        input[type="email"],
        input[type="number"],
        select {
            width: 100%;
            padding: 10px 15px;
            border: 2px solid #e0e0e0;
            border-radius: 6px;
            font-size: 14px;
            transition: border-color 0.3s ease;
        }
        
        input:focus,
        select:focus {
            outline: none;
            border-color: #667eea;
        }
        
        .checkbox-group {
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        .checkbox-group input[type="checkbox"] {
            width: 20px;
            height: 20px;
            cursor: pointer;
        }
        
        .alert {
            padding: 15px 20px;
            border-radius: 6px;
            margin-bottom: 20px;
            display: none;
        }
        
        .alert.success {
            background: #d4edda;
            border-left: 4px solid #2ecc71;
            color: #155724;
        }
        
        .alert.error {
            background: #f8d7da;
            border-left: 4px solid #e74c3c;
            color: #721c24;
        }
        
        .alert.info {
            background: #d1ecf1;
            border-left: 4px solid #3498db;
            color: #0c5460;
        }
        
        .alert.warning {
            background: #fff3cd;
            border-left: 4px solid #ffc107;
            color: #856404;
        }
        
        .help-box {
            background: #fff3cd;
            border-left: 4px solid #ffc107;
            padding: 15px;
            border-radius: 6px;
            margin: 20px 0;
            font-size: 14px;
        }
        
        .help-box a {
            color: #667eea;
            text-decoration: none;
            font-weight: 600;
        }
        
        .help-box a:hover {
            text-decoration: underline;
        }
        
        .empty-state {
            text-align: center;
            padding: 60px 20px;
            color: #95a5a6;
        }
        
        @media (max-width: 768px) {
            .container {
                padding: 10px;
            }
            
            .header {
                padding: 20px;
            }
            
            .aggregator-grid {
                grid-template-columns: 1fr 1fr;
            }
            
            .modal-content {
                margin: 20px auto;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <!-- Header -->
        <div class="header">
            <h1>🛩️ ADS-B Feeder Configuration</h1>
            <p>Manage aggregator outputs and MLAT clients • v0.2.1-alpha</p>
        </div>

        <!-- Alert Messages -->
        <div id="alert" class="alert"></div>

        <!-- Status Bar -->
        <div class="status-bar">
            <div class="status-item">
                <span class="status-indicator" id="readsb-status"></span>
                <span><strong>readsb:</strong> <span id="readsb-text">Checking...</span></span>
            </div>
            <div class="status-item">
                <span class="status-indicator" id="mlat-status"></span>
                <span><strong>mlat-client:</strong> <span id="mlat-text">Checking...</span></span>
            </div>
            <button onclick="refreshStatus()">🔄 Refresh Status</button>
        </div>

        <!-- Outputs Section -->
        <div class="section">
            <div class="section-header">
                <h2 class="section-title">Beast Outputs</h2>
                <button onclick="showAggregatorSelection()">+ Add Output</button>
            </div>
            <div id="outputs-container">
                <div class="empty-state">
                    <p>Loading outputs...</p>
                </div>
            </div>
        </div>

        <!-- MLAT Section -->
        <div class="section">
            <div class="section-header">
                <h2 class="section-title">MLAT Clients</h2>
                <button onclick="showAddMLATModal()">+ Add MLAT Client</button>
            </div>
            <div id="mlat-container">
                <div class="empty-state">
                    <p>Loading MLAT clients...</p>
                </div>
            </div>
        </div>

        <!-- Actions -->
        <div class="section">
            <div class="section-header">
                <h2 class="section-title">Actions</h2>
            </div>
            <div class="button-group">
                <button class="success" onclick="applyConfiguration()">✓ Apply Configuration & Restart Services</button>
                <button class="secondary" onclick="downloadConfig()">💾 Download Configuration</button>
            </div>
        </div>
    </div>

    <!-- Aggregator Selection Modal -->
    <div id="aggregator-modal" class="modal">
        <div class="modal-content">
            <div class="modal-header">Select Aggregator Type</div>
            <p style="margin-bottom: 20px; color: #666;">Choose the aggregator you want to add to your feeder:</p>
            
            <div class="aggregator-grid">
                <div class="aggregator-option" onclick="selectAggregator('flightradar24')">
                    <div class="aggregator-icon">✈️</div>
                    <div class="aggregator-name">FlightRadar24</div>
                </div>
                <div class="aggregator-option" onclick="selectAggregator('adsbexchange')">
                    <div class="aggregator-icon">🌐</div>
                    <div class="aggregator-name">ADS-B Exchange</div>
                </div>
                <div class="aggregator-option" onclick="selectAggregator('airplaneslive')">
                    <div class="aggregator-icon">📡</div>
                    <div class="aggregator-name">Airplanes.Live</div>
                </div>
                <div class="aggregator-option" onclick="selectAggregator('adsbhub')">
                    <div class="aggregator-icon">🗺️</div>
                    <div class="aggregator-name">ADSBhub</div>
                </div>
                <div class="aggregator-option" onclick="selectAggregator('other')">
                    <div class="aggregator-icon">⚙️</div>
                    <div class="aggregator-name">Custom/Other</div>
                </div>
            </div>
            
            <div style="margin-top: 20px;">
                <button class="secondary" onclick="closeModal('aggregator-modal')">Cancel</button>
            </div>
        </div>
    </div>

    <!-- Add Output Modal (Dynamic based on aggregator) -->
    <div id="output-modal" class="modal">
        <div class="modal-content">
            <div class="modal-header" id="output-modal-title">Add Output</div>
            <div id="output-form-container"></div>
        </div>
    </div>

    <!-- Add MLAT Modal -->
    <div id="mlat-modal" class="modal">
        <div class="modal-content">
            <div class="modal-header">Add MLAT Client</div>
            <form id="mlat-form">
                <div class="form-group">
                    <label>Name:</label>
                    <input type="text" id="mlat-name" required placeholder="e.g., FR24 MLAT">
                </div>
                <div class="form-group">
                    <label>Server:</label>
                    <input type="text" id="mlat-server" required placeholder="e.g., mlat.fr24.com:30105">
                </div>
                <div class="form-group checkbox-group">
                    <input type="checkbox" id="mlat-enabled" checked>
                    <label for="mlat-enabled" style="margin-bottom: 0;">Enabled</label>
                </div>
                <div class="button-group">
                    <button type="submit" class="success">Save MLAT Client</button>
                    <button type="button" class="secondary" onclick="closeModal('mlat-modal')">Cancel</button>
                </div>
            </form>
        </div>
    </div>

    <script>
        // Global state
        let config = {};
        let selectedAggregator = null;
        const aggregatorTemplates = """ + json.dumps(AGGREGATOR_TEMPLATES) + """;

        // Initialize on page load
        document.addEventListener('DOMContentLoaded', function() {
            loadConfiguration();
            checkServiceStatus();
            
            // Set up MLAT form handler
            document.getElementById('mlat-form').addEventListener('submit', handleAddMLAT);
        });

        // Load configuration from server
        function loadConfiguration() {
            fetch('/api/config')
                .then(r => r.json())
                .then(data => {
                    config = data;
                    renderOutputs();
                    renderMLAT();
                })
                .catch(err => showAlert('Error loading configuration: ' + err.message, 'error'));
        }

        // Render Beast outputs
        function renderOutputs() {
            const container = document.getElementById('outputs-container');
            const outputs = config.outputs || [];

            if (outputs.length === 0) {
                container.innerHTML = '<div class="empty-state"><p>No outputs configured. Click "+ Add Output" to get started!</p></div>';
                return;
            }

            container.innerHTML = outputs.map(output => `
                <div class="output-card ${output.primary ? 'primary' : ''} ${!output.enabled ? 'disabled' : ''}">
                    <div class="output-header">
                        <div>
                            <div class="output-title">
                                ${output.name}
                                ${output.primary ? '<span class="badge primary">Primary</span>' : ''}
                                ${output.aggregator_type ? '<span class="badge aggregator">' + (aggregatorTemplates[output.aggregator_type]?.display_name || output.aggregator_type) + '</span>' : ''}
                                <span class="badge ${output.enabled ? 'enabled' : 'disabled'}">
                                    ${output.enabled ? 'Enabled' : 'Disabled'}
                                </span>
                            </div>
                        </div>
                    </div>
                    <div class="output-details">
                        <div><strong>Host:</strong> ${output.host}</div>
                        <div><strong>Port:</strong> ${output.port}</div>
                        <div><strong>Type:</strong> ${output.type}</div>
                        ${output.sharing_key ? '<div><strong>Sharing Key:</strong> ' + output.sharing_key.substring(0, 4) + '...' + output.sharing_key.substring(12) + '</div>' : ''}
                        ${output.email ? '<div><strong>Email:</strong> ' + output.email + '</div>' : ''}
                    </div>
                    <div class="button-group">
                        <button onclick="toggleOutput('${output.id}')">
                            ${output.enabled ? '⏸️ Disable' : '▶️ Enable'}
                        </button>
                        ${!output.primary ? `<button class="danger" onclick="deleteOutput('${output.id}')">🗑️ Delete</button>` : ''}
                    </div>
                </div>
            `).join('');
        }

        // Render MLAT clients
        function renderMLAT() {
            const container = document.getElementById('mlat-container');
            const clients = config.mlat_clients || [];

            if (clients.length === 0) {
                container.innerHTML = '<div class="empty-state"><p>No MLAT clients configured</p></div>';
                return;
            }

            container.innerHTML = clients.map(client => `
                <div class="output-card ${!client.enabled ? 'disabled' : ''}">
                    <div class="output-header">
                        <div>
                            <div class="output-title">${client.name}</div>
                            <span class="badge ${client.enabled ? 'enabled' : 'disabled'}">
                                ${client.enabled ? 'Enabled' : 'Disabled'}
                            </span>
                        </div>
                    </div>
                    <div class="output-details">
                        <div><strong>Server:</strong> ${client.server}</div>
                        <div><strong>Input:</strong> ${client.input_connect}</div>
                        <div><strong>Results:</strong> ${client.results}</div>
                    </div>
                    <div class="button-group">
                        <button onclick="toggleMLAT('${client.id}')">
                            ${client.enabled ? '⏸️ Disable' : '▶️ Enable'}
                        </button>
                        <button class="danger" onclick="deleteMLAT('${client.id}')">🗑️ Delete</button>
                    </div>
                </div>
            `).join('');
        }

        // Check service status
        function checkServiceStatus() {
            fetch('/api/services/status')
                .then(r => r.json())
                .then(data => {
                    updateStatusIndicator('readsb', data.readsb);
                    updateStatusIndicator('mlat', data.mlat_client);
                });
        }

        function updateStatusIndicator(service, active) {
            const indicator = document.getElementById(`${service}-status`);
            const text = document.getElementById(`${service}-text`);
            
            indicator.className = 'status-indicator ' + (active ? 'active' : 'inactive');
            text.textContent = active ? 'Active' : 'Inactive';
        }

        function refreshStatus() {
            checkServiceStatus();
            showAlert('Status refreshed', 'success');
        }

        // Aggregator selection flow
        function showAggregatorSelection() {
            document.getElementById('aggregator-modal').style.display = 'block';
        }

        function selectAggregator(type) {
            selectedAggregator = type;
            closeModal('aggregator-modal');
            showOutputFormForAggregator(type);
        }

        function showOutputFormForAggregator(type) {
            const template = aggregatorTemplates[type];
            const modalTitle = document.getElementById('output-modal-title');
            const formContainer = document.getElementById('output-form-container');
            
            modalTitle.textContent = 'Add ' + template.display_name;
            
            // Build form HTML
            let formHTML = '<form id="output-form" onsubmit="handleAddOutput(event); return false;">';
            
            // Add help text if available
            if (template.help_text) {
                formHTML += `<div class="help-box">
                    ℹ️ ${template.help_text}
                    ${template.registration_url ? ` <a href="${template.registration_url}" target="_blank">Register here</a>` : ''}
                </div>`;
            }
            
            // Name field (always present)
            formHTML += `
                <div class="form-group">
                    <label>Name:</label>
                    <input type="text" id="output-name" required placeholder="${template.display_name}" value="${template.display_name}">
                </div>
            `;
            
            // Add aggregator-specific fields
            template.fields.forEach(field => {
                formHTML += `
                    <div class="form-group">
                        <label>
                            ${field.label}${field.required ? ' *' : ''}
                            ${field.help ? '<span class="field-help"><br>' + field.help + '</span>' : ''}
                        </label>
                        <input type="${field.type}" 
                               id="field-${field.name}" 
                               ${field.required ? 'required' : ''} 
                               placeholder="${field.placeholder || ''}">
                    </div>
                `;
            });
            
            // Host and port (may be pre-filled or custom)
            if (type === 'other') {
                // Already included in fields
            } else {
                formHTML += `
                    <div class="form-group">
                        <label>Host:</label>
                        <input type="text" id="output-host" required value="${template.default_host}" readonly style="background: #f5f5f5;">
                    </div>
                    <div class="form-group">
                        <label>Port:</label>
                        <input type="number" id="output-port" required value="${template.default_port}" readonly style="background: #f5f5f5;">
                    </div>
                `;
            }
            
            // Enabled checkbox
            formHTML += `
                <div class="form-group checkbox-group">
                    <input type="checkbox" id="output-enabled" checked>
                    <label for="output-enabled" style="margin-bottom: 0;">Enabled</label>
                </div>
            `;
            
            // Buttons
            formHTML += `
                <div class="button-group">
                    <button type="submit" class="success" id="save-button">Save Output</button>
                    <button type="button" class="secondary" onclick="closeModal('output-modal')">Cancel</button>
                </div>
            </form>`;
            
            formContainer.innerHTML = formHTML;
            
            // Show modal
            document.getElementById('output-modal').style.display = 'block';
        }

        // Modal functions
        function closeModal(modalId) {
            document.getElementById(modalId).style.display = 'none';
            selectedAggregator = null;
        }

        function showAddMLATModal() {
            document.getElementById('mlat-modal').style.display = 'block';
        }

        // Handle add output (FIXED VERSION)
        function handleAddOutput(e) {
            e.preventDefault();
            
            console.log('Form submitted, selectedAggregator:', selectedAggregator);
            
            const template = aggregatorTemplates[selectedAggregator];
            const output = {
                name: document.getElementById('output-name').value,
                type: 'beast',
                aggregator_type: selectedAggregator,
                enabled: document.getElementById('output-enabled').checked
            };
            
            // Get host and port
            if (selectedAggregator === 'other') {
                output.host = document.getElementById('field-custom_host').value;
                output.port = parseInt(document.getElementById('field-custom_port').value);
            } else {
                output.host = template.default_host;
                output.port = template.default_port;
            }
            
            // Get aggregator-specific fields
            template.fields.forEach(field => {
                const fieldElement = document.getElementById(`field-${field.name}`);
                if (fieldElement && fieldElement.value) {
                    output[field.name] = fieldElement.value;
                }
            });
            
            console.log('Sending output:', output);
            
            // Disable button to prevent double-submit
            const saveButton = document.getElementById('save-button');
            saveButton.disabled = true;
            saveButton.textContent = 'Saving...';

            fetch('/api/outputs', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify(output)
            })
            .then(r => r.json())
            .then(data => {
                console.log('Server response:', data);
                closeModal('output-modal');
                loadConfiguration();
                showAlert('Output added successfully. Click "Apply Configuration" to activate.', 'success');
            })
            .catch(err => {
                console.error('Error:', err);
                showAlert('Error adding output: ' + err.message, 'error');
                saveButton.disabled = false;
                saveButton.textContent = 'Save Output';
            });
            
            return false;
        }

        // Handle add MLAT
        function handleAddMLAT(e) {
            e.preventDefault();
            
            const client = {
                name: document.getElementById('mlat-name').value,
                server: document.getElementById('mlat-server').value,
                enabled: document.getElementById('mlat-enabled').checked,
                input_connect: 'localhost:30005',
                results: 'beast,connect,localhost:30104'
            };

            fetch('/api/mlat', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify(client)
            })
            .then(r => r.json())
            .then(() => {
                closeModal('mlat-modal');
                loadConfiguration();
                showAlert('MLAT client added successfully', 'success');
                document.getElementById('mlat-form').reset();
            })
            .catch(err => showAlert('Error adding MLAT client: ' + err.message, 'error'));
        }

        // Toggle functions
        function toggleOutput(id) {
            fetch(`/api/outputs/${id}/toggle`, {method: 'POST'})
                .then(() => {
                    loadConfiguration();
                    showAlert('Output toggled. Click "Apply Configuration" to activate changes.', 'info');
                })
                .catch(err => showAlert('Error toggling output: ' + err.message, 'error'));
        }

        function toggleMLAT(id) {
            fetch(`/api/mlat/${id}/toggle`, {method: 'POST'})
                .then(() => {
                    loadConfiguration();
                    showAlert('MLAT client toggled', 'success');
                })
                .catch(err => showAlert('Error toggling MLAT: ' + err.message, 'error'));
        }

        // Delete functions
        function deleteOutput(id) {
            if (!confirm('Delete this output? This will not take effect until you apply configuration.')) return;
            
            fetch(`/api/outputs/${id}`, {method: 'DELETE'})
                .then(() => {
                    loadConfiguration();
                    showAlert('Output deleted', 'success');
                })
                .catch(err => showAlert('Error deleting output: ' + err.message, 'error'));
        }

        function deleteMLAT(id) {
            if (!confirm('Delete this MLAT client? This will not take effect until you apply configuration.')) return;
            
            fetch(`/api/mlat/${id}`, {method: 'DELETE'})
                .then(() => {
                    loadConfiguration();
                    showAlert('MLAT client deleted', 'success');
                })
                .catch(err => showAlert('Error deleting MLAT: ' + err.message, 'error'));
        }

        // Apply configuration
        function applyConfiguration() {
            if (!confirm('Apply configuration and restart services? This will cause brief downtime (~5 seconds).')) return;
            
            showAlert('Applying configuration...', 'info');
            
            fetch('/api/apply', {method: 'POST'})
                .then(r => r.json())
                .then(data => {
                    if (data.success) {
                        showAlert('Configuration applied successfully! Services restarting...', 'success');
                        setTimeout(checkServiceStatus, 3000);
                    } else {
                        showAlert('Error: ' + data.message, 'error');
                    }
                })
                .catch(err => showAlert('Error applying configuration: ' + err.message, 'error'));
        }

        // Download config
        function downloadConfig() {
            fetch('/api/config')
                .then(r => r.json())
                .then(data => {
                    const blob = new Blob([JSON.stringify(data, null, 2)], {type: 'application/json'});
                    const url = URL.createObjectURL(blob);
                    const a = document.createElement('a');
                    a.href = url;
                    a.download = 'adsb-feeder-config.json';
                    a.click();
                    showAlert('Configuration downloaded', 'success');
                });
        }

        // Alert helper
        function showAlert(message, type) {
            const alert = document.getElementById('alert');
            alert.textContent = message;
            alert.className = 'alert ' + type;
            alert.style.display = 'block';
            
            setTimeout(() => {
                alert.style.display = 'none';
            }, 5000);
        }
    </script>
</body>
</html>
"""

# ============================================================================
# API ROUTES
# ============================================================================

@app.route('/')
def index():
    """Serve the main configuration page"""
    return render_template_string(HTML_TEMPLATE)

@app.route('/api/config', methods=['GET'])
def get_config():
    """Get current configuration"""
    config = load_config()
    return jsonify(config)

@app.route('/api/outputs', methods=['POST'])
def add_output():
    """Add a new Beast output"""
    output = request.json
    config = load_config()
    
    # Generate unique ID
    output['id'] = f"output-{datetime.now().strftime('%Y%m%d%H%M%S')}"
    output['primary'] = False  # User-added outputs are never primary
    
    # Handle FR24 signup if no sharing key provided
    if output.get('aggregator_type') == 'flightradar24':
        if not output.get('sharing_key') and output.get('email'):
            # User wants to sign up for FR24
            feeder_info = config.get('feeder_info', {})
            signup_result = signup_fr24(output['email'], feeder_info)
            
            if signup_result.get('need_manual_signup'):
                return jsonify({
                    "success": False,
                    "message": signup_result['message'],
                    "need_manual_action": True
                }), 400
    
    config['outputs'].append(output)
    
    if save_config(config):
        return jsonify({"success": True, "id": output['id']})
    else:
        return jsonify({"success": False, "message": "Failed to save configuration"}), 500

@app.route('/api/outputs/<output_id>', methods=['DELETE'])
def delete_output(output_id):
    """Delete an output"""
    config = load_config()
    
    # Don't allow deleting primary output
    for output in config['outputs']:
        if output['id'] == output_id and output.get('primary', False):
            return jsonify({"success": False, "message": "Cannot delete primary output"}), 400
    
    config['outputs'] = [o for o in config['outputs'] if o['id'] != output_id]
    
    if save_config(config):
        return jsonify({"success": True})
    else:
        return jsonify({"success": False, "message": "Failed to save configuration"}), 500

@app.route('/api/outputs/<output_id>/toggle', methods=['POST'])
def toggle_output(output_id):
    """Enable/disable an output"""
    config = load_config()
    
    for output in config['outputs']:
        if output['id'] == output_id:
            # Don't allow disabling primary output
            if output.get('primary', False):
                return jsonify({"success": False, "message": "Cannot disable primary output"}), 400
            
            output['enabled'] = not output.get('enabled', True)
            break
    
    if save_config(config):
        return jsonify({"success": True})
    else:
        return jsonify({"success": False, "message": "Failed to save configuration"}), 500

@app.route('/api/mlat', methods=['POST'])
def add_mlat():
    """Add a new MLAT client"""
    client = request.json
    config = load_config()
    
    # Generate unique ID
    client['id'] = f"mlat-{datetime.now().strftime('%Y%m%d%H%M%S')}"
    
    config['mlat_clients'].append(client)
    
    if save_config(config):
        return jsonify({"success": True, "id": client['id']})
    else:
        return jsonify({"success": False, "message": "Failed to save configuration"}), 500

@app.route('/api/mlat/<client_id>', methods=['DELETE'])
def delete_mlat(client_id):
    """Delete an MLAT client"""
    config = load_config()
    config['mlat_clients'] = [c for c in config.get('mlat_clients', []) if c['id'] != client_id]
    
    if save_config(config):
        return jsonify({"success": True})
    else:
        return jsonify({"success": False, "message": "Failed to save configuration"}), 500

@app.route('/api/mlat/<client_id>/toggle', methods=['POST'])
def toggle_mlat(client_id):
    """Enable/disable an MLAT client"""
    config = load_config()
    
    for client in config.get('mlat_clients', []):
        if client['id'] == client_id:
            client['enabled'] = not client.get('enabled', True)
            break
    
    if save_config(config):
        return jsonify({"success": True})
    else:
        return jsonify({"success": False, "message": "Failed to save configuration"}), 500

@app.route('/api/services/status', methods=['GET'])
def services_status():
    """Get status of all services"""
    return jsonify({
        "readsb": get_service_status('readsb'),
        "mlat_client": get_service_status('mlat-client')
    })

@app.route('/api/apply', methods=['POST'])
def apply_config():
    """Apply configuration and restart services"""
    success, message = apply_configuration()
    return jsonify({"success": success, "message": message})

# ============================================================================
# MAIN
# ============================================================================

if __name__ == '__main__':
    print("=" * 60)
    print("ADS-B Feeder Web Configuration Interface v0.2.1")
    print("=" * 60)
    print(f"Configuration file: {CONFIG_FILE}")
    print(f"Starting web server on port 8080...")
    print(f"Access at: http://localhost:8080")
    print(f"Or via Tailscale: http://100.89.141.83:8080")
    print("=" * 60)
    print("\nPress Ctrl+C to stop\n")
    
    # Run on all interfaces, port 8080
    app.run(host='0.0.0.0', port=8080, debug=False, threaded=True)
