import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Transaction } from './transaction.entity';
import { Readable } from 'stream';

const csv = require('csv-parser'); 

@Injectable()
export class TransactionsService {
  constructor(
    @InjectRepository(Transaction)
    private transactionsRepository: Repository<Transaction>,
  ) {}

  // Added userId parameter so we can link the data to the logged-in user
  async parseCsvBuffer(buffer: Buffer, userId: string): Promise<any[]> {
    return new Promise((resolve, reject) => {
      const results: any[] = [];
      const stream = Readable.from(buffer);

      stream
        .pipe(csv()) 
        .on('data', (row) => {
          // --- 1. Basic Formatting ---
          const description = row['Narration'] || 'Unknown';
          const refNumber = row['Chq./Ref.No.'] || null;
          let amount = 0;
          let isDebit = false;

          if (row['Withdrawal Amt.'] && row['Withdrawal Amt.'].trim() !== '') {
            amount = parseFloat(row['Withdrawal Amt.']) || 0;
            isDebit = true;
          } else if (row['Deposit Amt.'] && row['Deposit Amt.'].trim() !== '') {
            amount = parseFloat(row['Deposit Amt.']) || 0;
            isDebit = false;
          }

          if (amount === 0) return; // Skip empty rows

          // --- 2. Date & Financial Year Logic ---
          // Assuming CSV date format is DD/MM/YY (e.g., '01/01/23')
          let txDate = new Date();
          let financialYear = 'Unknown';
          
          if (row['Date']) {
            const dateParts = row['Date'].split('/');
            if (dateParts.length === 3) {
              const day = parseInt(dateParts[0], 10);
              const month = parseInt(dateParts[1], 10) - 1; // JS months are 0-indexed
              const year = 2000 + parseInt(dateParts[2], 10); // '23' -> 2023
              txDate = new Date(year, month, day);

              // Calculate Indian Financial Year (Starts April 1st)
              const txYear = txDate.getFullYear();
              const txMonth = txDate.getMonth(); // 3 = April
              financialYear = txMonth >= 3 ? `${txYear}-${txYear + 1}` : `${txYear - 1}-${txYear}`;
            }
          }

          // --- 3. The Formatted Entity ---
          const formattedTx = this.transactionsRepository.create({
            user_id: userId, // Link to the user
            transaction_date: txDate,
            financial_year: financialYear,
            merchant_name: description,
            reference_number: refNumber,
            amount: Math.abs(amount), 
            transaction_type: isDebit ? 'debit' : 'credit',
            category: isDebit ? 'Expense' : 'Income', 
            classification: isDebit ? 'Uncategorized' : 'Income', 
            is_reviewed: !isDebit, 
          });
          
          results.push(formattedTx);
        })
        .on('end', async () => {
          // Note: Removing clear() so we don't delete other users' data!
          // await this.transactionsRepository.clear(); 
          
          const savedTransactions = await this.transactionsRepository.save(results); 
          resolve(savedTransactions);
        })
        .on('error', (error) => reject(error));
    });
  }

  async getAllTransactions(userId: string) {
    // IMPORTANT: Sort by date, not ID, since UUIDs are random strings
    // Also filtering by userId so users only see their own data
    return this.transactionsRepository.find({ 
      where: { user_id: userId },
      order: { transaction_date: 'DESC' } 
    });
  }

  async getSummary(userId: string) {
    // 1. Fetch all transactions for this specific user
    const transactions = await this.transactionsRepository.find({
      where: { user_id: userId },
    });

    let totalIncome = 0;
    let totalExpense = 0;

    // 2. The Smart Categorization Engine
    for (const tx of transactions) {
      const amount = Number(tx.amount);
      const classification = tx.classification;
      const type = tx.transaction_type;

      if (classification === 'Salary' || classification === 'Interest') {
        // --- BUCKET 1: True Wealth Generators ---
        totalIncome += amount;

      } else if (classification === 'Necessary' || classification === 'Leak') {
        // --- BUCKET 2: Standard Expenses ---
        totalExpense += amount;

      } else if (classification === 'Refund' || classification === 'Reimbursement') {
        // --- BUCKET 3: Expense Offsets (The clever part) ---
        // Instead of adding to income, we SUBTRACT this from expenses!
        totalExpense -= amount;

      } else if (classification === 'Transfer' || classification === 'Adjustment') {
        // --- BUCKET 4: Neutral Noise ---
        // Do absolutely nothing. We ignore these entirely.
        continue;

      } else {
        // --- FALLBACK: Uncategorized Transactions ---
        // If the AI or user hasn't categorized it yet, we default to basic logic
        // so your charts aren't completely empty when you first upload a CSV.
        if (type === 'credit') {
          totalIncome += amount;
        } else if (type === 'debit') {
          totalExpense += amount;
        }
      }
    }

    // 3. Safety Check: If refunds are larger than expenses, prevent negative expenses
    if (totalExpense < 0) totalExpense = 0;

    return {
      income: totalIncome,
      expense: totalExpense,
      balance: totalIncome - totalExpense,
    };
  }

  // FIX: Changed id from 'number' to 'string'
  async categorizeTransaction(id: string, classification: string) {
    const transaction = await this.transactionsRepository.findOne({ where: { id } });
    
    if (!transaction) {
      throw new NotFoundException(`Transaction with ID ${id} not found`);
    }

    transaction.classification = classification;
    transaction.is_reviewed = true; 
    
    return this.transactionsRepository.save(transaction);
  }
}