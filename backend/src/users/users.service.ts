import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User, UserRole } from './entities/user.entity';
import { OrganizationsService } from '../organizations/organizations.service';
import { CreateUserDto } from './dto/create-user.dto';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private readonly usersRepository: Repository<User>,
    private readonly organizationsService: OrganizationsService,
  ) {}

  async create(createUserDto: CreateUserDto): Promise<User> {
    const { email, password, organizationName } = createUserDto;

    // For the first user, we create a new organization
    const organization = await this.organizationsService.create(
      organizationName,
    );

    const user = this.usersRepository.create({
      email,
      password_hash: password, // Hashing is handled by the @BeforeInsert hook
      organization_id: organization.id,
      role: UserRole.OWNER, // The first user is the owner
    });

    return this.usersRepository.save(user);
  }

  async findOneByEmail(email: string): Promise<User | undefined> {
    return this.usersRepository.findOne({ where: { email } });
  }

  async findOneById(id: string): Promise<User | undefined> {
    return this.usersRepository.findOne({ where: { id } });
  }
}
