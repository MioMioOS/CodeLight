export const config = {
    port: parseInt(process.env.PORT || '3005', 10),
    masterSecret: process.env.MASTER_SECRET || '',
    databaseUrl: process.env.DATABASE_URL || '',
} as const;
