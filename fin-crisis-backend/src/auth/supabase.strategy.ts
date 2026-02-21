// src/auth/supabase.strategy.ts
import { ExtractJwt, Strategy } from 'passport-jwt';
import { PassportStrategy } from '@nestjs/passport';
import { Injectable } from '@nestjs/common';
import { passportJwtSecret } from 'jwks-rsa'; // <-- NEW: Import the key fetcher

@Injectable()
export class SupabaseStrategy extends PassportStrategy(Strategy) {
  constructor() {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      
      // --- NEW: Fetch the public key from Supabase dynamically ---
      secretOrKeyProvider: passportJwtSecret({
        cache: true,
        rateLimit: true,
        jwksRequestsPerMinute: 5,
        // This is the standard Supabase endpoint for public keys
        jwksUri: `${process.env.SUPABASE_URL}/auth/v1/.well-known/jwks.json`,
      }),
      
      // --- NEW: Tell Passport to expect the new Asymmetric algorithms ---
      algorithms: ['ES256', 'RS256'],
    });
  }

  async validate(payload: any) {
    return { userId: payload.sub, email: payload.email };
  }
}