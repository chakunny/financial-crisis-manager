import { 
  Controller, Post, Get, Patch, Param, Body, 
  UseInterceptors, UploadedFile, BadRequestException,
  UseGuards, Req // <-- 1. Import these
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { TransactionsService } from './transactions.service';
import { AuthGuard } from '@nestjs/passport'; // <-- 2. Import AuthGuard

@UseGuards(AuthGuard('jwt')) // <-- 3. THIS LOCKS THE ENTIRE CONTROLLER
@Controller('transactions')
export class TransactionsController {
  constructor(private readonly transactionsService: TransactionsService) {}

  @Post('upload')
  @UseInterceptors(FileInterceptor('file'))
  async uploadFile(@UploadedFile() file: Express.Multer.File, @Req() req: any) {
    if (!file) throw new BadRequestException('No file uploaded.');
    
    // 4. Extract the real User ID from the validated token!
    const realUserId = req.user.userId; 
    
    const parsedData = await this.transactionsService.parseCsvBuffer(file.buffer, realUserId);
    return { message: 'Success', data: parsedData };
  }

  @Get()
  getTransactions(@Req() req: any) {
    return this.transactionsService.getAllTransactions(req.user.userId);
  }

  @Get('summary')
  getSummary(@Req() req: any) {
    return this.transactionsService.getSummary(req.user.userId);
  }

  @Patch(':id/categorize')
  async categorize(
    @Param('id') id: string,
    @Body() body: any 
  ) {
    const classification = body.classification;
    return this.transactionsService.categorizeTransaction(id, classification);
  }
}