// prisma/seed.js
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  // Branches
  const tuv = await prisma.branch.upsert({
    where: { code: 'TUV' },
    update: {},
    create: { code: 'TUV', name: 'Tuv Salbar', address: 'Ulaanbaatar', phone: '7700-0001' },
  });

  const maral = await prisma.branch.upsert({
    where: { code: 'MARAL' },
    update: {},
    create: { code: 'MARAL', name: 'Maral Salbar', address: 'Ulaanbaatar', phone: '7700-0002' },
  });

  // Rooms
  const room1 = await prisma.room.create({ data: { name: 'Room 1', branchId: tuv.id } });
  const room2 = await prisma.room.create({ data: { name: 'Room 2', branchId: tuv.id } });

  // Doctors
  const drEelen = await prisma.doctor.create({
    data: { fullName: 'Dr. Eelen', branchId: tuv.id, phone: '9911-0001' },
  });

  // Patients (regNo unique, phone not unique)
  const patientTemu = await prisma.patient.create({
    data: {
      fullName: 'Temuujin Baatar',
      regNo: 'АА12345678',
      phone: '99110002',
      gender: 'MALE',
      branchId: tuv.id,
      birthDate: new Date('2015-06-01'),
    },
  });

  // History book
  await prisma.historyBook.create({
    data: { patientId: patientTemu.id, bookNumber: 'HB-00001' },
  });

  // Appointment
  const now = new Date();
  const in30 = new Date(now.getTime() + 30 * 60 * 1000);
  const appt = await prisma.appointment.create({
    data: {
      patientId: patientTemu.id,
      doctorId: drEelen.id,
      branchId: tuv.id,
      roomId: room1.id,
      startsAt: now,
      endsAt: in30,
      status: 'SCHEDULED',
      notes: 'Initial checkup',
    },
  });

  // Encounter + notes
  const enc = await prisma.encounter.create({
    data: {
      patientId: patientTemu.id,
      doctorId: drEelen.id,
      branchId: tuv.id,
      occurredAt: now,
      reason: 'Tooth sensitivity',
      notes: 'Mild sensitivity on 26.',
    },
  });

  await prisma.chartNote.create({
    data: {
      encounterId: enc.id,
      patientId: patientTemu.id,
      toothCode: '26', // FDI
      note: 'Visible white spot, early demineralization.',
    },
  });

  // Procedure + Invoice + Payment
  const proc = await prisma.procedure.create({
    data: {
      encounterId: enc.id,
      patientId: patientTemu.id,
      code: 'FL-26',
      name: 'Fluoride varnish (tooth 26)',
      toothCode: '26',
      unitPrice: 25000.00,
      quantity: 1,
      totalAmount: 25000.00,
    },
  });

  const inv = await prisma.invoice.create({
    data: {
      patientId: patientTemu.id,
      encounterId: enc.id,
      branchId: tuv.id,
      number: 'INV-00001',
      status: 'PAID',
      subtotal: 25000.00,
      tax: 0,
      discount: 0,
      total: 25000.00,
      items: {
        create: [{
          description: 'Fluoride varnish (26)',
          procedureId: proc.id,
          quantity: 1,
          unitPrice: 25000.00,
          total: 25000.00,
        }],
      },
      payments: {
        create: [{
          method: 'CASH',
          amount: 25000.00,
          paidAt: new Date(),
        }],
      },
    },
  });

  console.log({ branches: [tuv.code, maral.code], room1: room1.name, doctor: drEelen.fullName, patient: patientTemu.fullName, appt: appt.id, encounter: enc.id, invoice: inv.number });
}

main()
  .catch((e) => { console.error(e); process.exit(1); })
  .finally(async () => { await prisma.$disconnect(); });
