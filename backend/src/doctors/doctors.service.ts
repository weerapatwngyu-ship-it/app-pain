import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CreateDoctorDto } from './dto/create-doctor.dto';
import { UpdateDoctorDto } from './dto/update-doctor.dto';
import { Doctor } from './entities/doctor.entity';

@Injectable()
export class DoctorsService {
  constructor(@InjectRepository(Doctor) private readonly doctors: Repository<Doctor>) {}

  create(dto: CreateDoctorDto) {
    return this.doctors.save(this.doctors.create(dto));
  }

  findAll() {
    return this.doctors.find({ order: { createdAt: 'DESC' } });
  }

  async findOne(id: string) {
    const doctor = await this.doctors.findOne({ where: { id } });
    if (!doctor) throw new NotFoundException('ไม่พบข้อมูลแพทย์');
    return doctor;
  }

  async update(id: string, dto: UpdateDoctorDto) {
    const doctor = await this.findOne(id);
    Object.assign(doctor, dto);
    return this.doctors.save(doctor);
  }

  async updatePhoto(id: string, photoUrl: string) {
    const doctor = await this.findOne(id);
    doctor.photoUrl = photoUrl;
    return this.doctors.save(doctor);
  }
}
