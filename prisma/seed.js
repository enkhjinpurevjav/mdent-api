import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  // 1. Admin user (upsert = create if not exists)
  const admin = await prisma.user.upsert({
    where: { email: 'admin@mdent.cloud' },
    update: {},
    create: {
      email: 'admin@mdent.cloud',
      name: 'Admin',
      role: 'ADMIN',
      password: 'changeme123', // ⚠️ plain text for testing only — hash later
    },
  });

  // 2. Patient
  const patient = await prisma.patient.create({
    data: {
      firstName: 'John',
      lastName: 'Doe',
      phone: '+976-88888888',
      email: 'john.doe@example.com',
      notes: 'Test patient created from seed.js',
    },
  });

  // 3. Appointment
  await prisma.appointment.create({
    data: {
      patientId: patient.id,
      userId: admin.id,
      startsAt: new Date(Date.now() + 60 * 60 * 1000),
      endsAt: new Date(Date.now() + 2 * 60 * 60 * 1000),
      status: 'SCHEDULED',
      notes: 'Initial checkup appointment',
    },
  });

  console.log('✅ Seed completed');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
