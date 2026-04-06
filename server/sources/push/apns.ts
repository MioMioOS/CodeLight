import { SignJWT, importPKCS8 } from 'jose';
import http2 from 'node:http2';
import { config } from '@/config';

/**
 * APNs push notification sender.
 * Uses Apple's HTTP/2 APNs API with JWT authentication.
 *
 * Required env vars:
 * - APNS_KEY_ID: Key ID from Apple Developer portal
 * - APNS_TEAM_ID: Apple Developer Team ID
 * - APNS_KEY: Base64-encoded .p8 private key content
 * - APNS_BUNDLE_ID: App bundle ID (e.g., com.codelight.app)
 */

interface APNsConfig {
    keyId: string;
    teamId: string;
    privateKey: string; // base64-encoded .p8 content
    bundleId: string;
    production: boolean;
}

function getApnsConfig(): APNsConfig | null {
    const keyId = process.env.APNS_KEY_ID;
    const teamId = process.env.APNS_TEAM_ID;
    const privateKey = process.env.APNS_KEY;
    const bundleId = process.env.APNS_BUNDLE_ID || 'com.codelight.app';

    if (!keyId || !teamId || !privateKey) {
        return null;
    }

    return {
        keyId,
        teamId,
        privateKey,
        bundleId,
        // APNS_USE_SANDBOX=true for development-signed apps (Xcode runs)
        production: process.env.APNS_USE_SANDBOX !== 'true' && process.env.NODE_ENV === 'production',
    };
}

let cachedToken: { token: string; expiresAt: number } | null = null;

async function getAuthToken(apnsConfig: APNsConfig): Promise<string> {
    // Reuse token if still valid (tokens last 60 min, refresh at 50 min)
    if (cachedToken && cachedToken.expiresAt > Date.now()) {
        return cachedToken.token;
    }

    const keyData = Buffer.from(apnsConfig.privateKey, 'base64').toString('utf-8');
    const privateKey = await importPKCS8(keyData, 'ES256');

    const token = await new SignJWT({})
        .setProtectedHeader({ alg: 'ES256', kid: apnsConfig.keyId })
        .setIssuer(apnsConfig.teamId)
        .setIssuedAt()
        .sign(privateKey);

    cachedToken = {
        token,
        expiresAt: Date.now() + 50 * 60 * 1000, // 50 minutes
    };

    return token;
}

export interface PushPayload {
    title: string;
    body: string;
    data?: Record<string, string>;
}

/**
 * Send a push notification to a device token.
 */
export async function sendPush(deviceToken: string, payload: PushPayload): Promise<boolean> {
    const apnsConfig = getApnsConfig();
    if (!apnsConfig) {
        console.log('[APNs] Not configured, skipping push');
        return false;
    }

    const host = apnsConfig.production
        ? 'https://api.push.apple.com'
        : 'https://api.sandbox.push.apple.com';

    const url = `${host}/3/device/${deviceToken}`;

    try {
        const authToken = await getAuthToken(apnsConfig);

        const apnsPayload = {
            aps: {
                alert: {
                    title: payload.title,
                    body: payload.body,
                },
                sound: 'default',
                'mutable-content': 1,
            },
            ...(payload.data || {}),
        };

        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'authorization': `bearer ${authToken}`,
                'apns-topic': apnsConfig.bundleId,
                'apns-push-type': 'alert',
                'apns-priority': '10',
                'content-type': 'application/json',
            },
            body: JSON.stringify(apnsPayload),
        });

        if (response.ok) {
            return true;
        }

        const errorBody = await response.text();
        console.error(`[APNs] Push failed: ${response.status} ${errorBody}`);

        return false;
    } catch (error) {
        console.error('[APNs] Push error:', error);
        return false;
    }
}

/**
 * Send push to all tokens for a device.
 */
export async function sendPushToDevice(
    deviceId: string,
    payload: PushPayload,
    db: any
): Promise<void> {
    const tokens = await db.pushToken.findMany({
        where: { deviceId },
        select: { token: true },
    });

    await Promise.allSettled(
        tokens.map((t: { token: string }) => sendPush(t.token, payload))
    );
}

/**
 * Live Activity ContentState matching CodeLightActivityAttributes.ContentState.
 */
export interface LiveActivityContentState {
    phase: string;
    toolName: string | null;
    projectName: string;
    lastUserMessage: string | null;
    lastAssistantSummary: string | null;
    startedAt: number; // unix timestamp
}

/**
 * Send HTTP/2 request to APNs (required — fetch() uses HTTP/1.1).
 */
function apnsHttp2Request(host: string, path: string, headers: Record<string, string>, body: string): Promise<{ status: number; body: string }> {
    return new Promise((resolve, reject) => {
        const client = http2.connect(host);

        client.on('error', (err) => {
            client.close();
            reject(err);
        });

        const req = client.request({
            ':method': 'POST',
            ':path': path,
            ...headers,
        });

        let responseBody = '';
        let statusCode = 0;

        req.on('response', (headers) => {
            statusCode = headers[':status'] as number;
        });

        req.on('data', (chunk) => {
            responseBody += chunk.toString();
        });

        req.on('end', () => {
            client.close();
            resolve({ status: statusCode, body: responseBody });
        });

        req.on('error', (err) => {
            client.close();
            reject(err);
        });

        req.write(body);
        req.end();
    });
}

/**
 * Send a Live Activity update via APNs push.
 * This updates an existing Live Activity on the device.
 */
export async function sendLiveActivityUpdate(
    pushToken: string,
    contentState: LiveActivityContentState,
    event: 'update' | 'end' = 'update'
): Promise<boolean> {
    const apnsConfig = getApnsConfig();
    if (!apnsConfig) {
        console.log('[APNs] Not configured, skipping Live Activity push');
        return false;
    }

    const host = apnsConfig.production
        ? 'https://api.push.apple.com'
        : 'https://api.sandbox.push.apple.com';

    try {
        const authToken = await getAuthToken(apnsConfig);

        const apnsPayload: any = {
            aps: {
                timestamp: Math.floor(Date.now() / 1000),
                event,
                'content-state': contentState,
            },
        };

        if (event === 'end') {
            apnsPayload.aps['dismissal-date'] = Math.floor(Date.now() / 1000) + 5;
        }

        const headers = {
            'authorization': `bearer ${authToken}`,
            'apns-topic': `${apnsConfig.bundleId}.push-type.liveactivity`,
            'apns-push-type': 'liveactivity',
            'apns-priority': '10',
            'content-type': 'application/json',
        };

        const result = await apnsHttp2Request(host, `/3/device/${pushToken}`, headers, JSON.stringify(apnsPayload));

        if (result.status === 200) {
            console.log(`[APNs LiveActivity] Push sent: phase=${contentState.phase}`);
            return true;
        }

        console.error(`[APNs LiveActivity] Push failed: ${result.status} ${result.body}`);
        return false;
    } catch (error) {
        console.error('[APNs LiveActivity] Push error:', error);
        return false;
    }
}
