import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule } from '@nestjs/config'; 
import { PassportModule } from '@nestjs/passport'; // <-- NEW: Required for Auth
import { TransactionsModule } from './transactions/transactions.module';
import { Transaction } from './transactions/transaction.entity';
import { SupabaseStrategy } from './auth/supabase.strategy'; // <-- NEW: Our custom security bouncer

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }), 

    // (Supabase PostgreSQL configuration)
    TypeOrmModule.forRoot({
      type: 'postgres',
      url: process.env.DATABASE_URL, 
      autoLoadEntities: true,
      synchronize: true, // Auto-creates tables (Keep true for Dev, False for Production)
      ssl: {
        rejectUnauthorized: false, // Required for Supabase connections
      },
      extra: {
        family: 4, // This forces the driver to use IPv4 only
      },
    }),
    // ------------------------------------------------

    PassportModule, // <-- NEW: Tells NestJS to enable authentication
    TransactionsModule,
  ],
  controllers: [],
  providers: [SupabaseStrategy], // <-- NEW: Registers the Supabase JWT checker
})
export class AppModule {}