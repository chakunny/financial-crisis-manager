import { 
  Entity, 
  Column, 
  PrimaryGeneratedColumn, 
  CreateDateColumn, 
  UpdateDateColumn 
} from 'typeorm';

@Entity('transactions')
export class Transaction {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid', name: 'user_id' })
  user_id: string;

  @Column()
  merchant_name: string;

  // Added reference_number to capture "Chq./Ref.No."
  @Column({ nullable: true })
  reference_number: string; 

  @Column('decimal', { precision: 12, scale: 2 })
  amount: number;

  @Column()
  transaction_type: string; // 'credit' or 'debit'

  @Column({ default: 'Uncategorized' })
  category: string; 

  @Column({ default: 'Uncategorized' }) 
  classification: string; // 'Leak', 'Necessary', 'Income', 'Refund'

  @Column({ default: false })
  is_reviewed: boolean; 

  @Column({ type: 'date', name: 'transaction_date' })
  transaction_date: Date;

  @Column({ type: 'varchar', length: 9, name: 'financial_year' })
  financial_year: string; 

  @CreateDateColumn({ name: 'created_at' })
  created_at: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updated_at: Date;
}