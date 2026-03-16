import { Test, TestingModule } from '@nestjs/testing';
import { ApprovalsController } from './approvals.controller';

describe('ApprovalsController', () => {
  let controller: ApprovalsController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [ApprovalsController],
    }).useMocker(() => ({})).compile();

    controller = module.get<ApprovalsController>(ApprovalsController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });
});


