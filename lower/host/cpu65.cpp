/* GSSquared's 65816 core, with nothing else from GSSquared: a three-bank
 * memory map, a call stub, and WDM traps back to the host. */
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <memory>
#include <string>

/* The core reaches memory only through these three. */
class MMU {
public:
	virtual ~MMU() = default;
	virtual uint8_t read(uint32_t address) = 0;
	virtual void write(uint32_t address, uint8_t value) = 0;
	virtual uint8_t vp_read(uint32_t address) { return read(address); }
};

#include "cpus/cpu_65816.cpp"

#include "l65.h"

/* cpu.cpp allocates a trace buffer; the harness keeps its own trace. */
system_trace_buffer::system_trace_buffer(size_t, processor_type type)
	: entries(nullptr), size(0), head(0), tail(0), count(0), cpu_type(type),
	  cpu_mask(0)
{
}
system_trace_buffer::~system_trace_buffer() {}
void system_trace_buffer::add_entry(const system_trace_entry_t &) {}

namespace {

/* Opcode mnemonics, for the trace only. */
const char *const k_mnem[256] = {
	"BRK","ORA","COP","ORA","TSB","ORA","ASL","ORA","PHP","ORA","ASL","PHD","TSB","ORA","ASL","ORA",
	"BPL","ORA","ORA","ORA","TRB","ORA","ASL","ORA","CLC","ORA","INC","TCS","TRB","ORA","ASL","ORA",
	"JSR","AND","JSL","AND","BIT","AND","ROL","AND","PLP","AND","ROL","PLD","BIT","AND","ROL","AND",
	"BMI","AND","AND","AND","BIT","AND","ROL","AND","SEC","AND","DEC","TSC","BIT","AND","ROL","AND",
	"RTI","EOR","WDM","EOR","MVP","EOR","LSR","EOR","PHA","EOR","LSR","PHK","JMP","EOR","LSR","EOR",
	"BVC","EOR","EOR","EOR","MVN","EOR","LSR","EOR","CLI","EOR","PHY","TCD","JML","EOR","LSR","EOR",
	"RTS","ADC","PER","ADC","STZ","ADC","ROR","ADC","PLA","ADC","ROR","RTL","JMP","ADC","ROR","ADC",
	"BVS","ADC","ADC","ADC","STZ","ADC","ROR","ADC","SEI","ADC","PLY","TDC","JMP","ADC","ROR","ADC",
	"BRA","STA","BRL","STA","STY","STA","STX","STA","DEY","BIT","TXA","PHB","STY","STA","STX","STA",
	"BCC","STA","STA","STA","STY","STA","STX","STA","TYA","STA","TXS","TXY","STZ","STA","STZ","STA",
	"LDY","LDA","LDX","LDA","LDY","LDA","LDX","LDA","TAY","LDA","TAX","PLB","LDY","LDA","LDX","LDA",
	"BCS","LDA","LDA","LDA","LDY","LDA","LDX","LDA","CLV","LDA","TSX","TYX","LDY","LDA","LDX","LDA",
	"CPY","CMP","REP","CMP","CPY","CMP","DEC","CMP","INY","CMP","DEX","WAI","CPY","CMP","DEC","CMP",
	"BNE","CMP","CMP","CMP","PEI","CMP","DEC","CMP","CLD","CMP","PHX","STP","JML","CMP","DEC","CMP",
	"CPX","SBC","SEP","SBC","CPX","SBC","INC","SBC","INX","SBC","NOP","XBA","CPX","SBC","INC","SBC",
	"BEQ","SBC","SBC","SBC","PEA","SBC","INC","SBC","SED","SBC","PLX","XCE","JSR","SBC","INC","SBC",
};

const uint8_t WDM_FAULT = 0x03;
const uint16_t FAULT_STUB = 0x0310;
const unsigned long MAX_INSNS = 20000000ul;

class LowerMMU : public MMU {
public:
	uint8_t bank0[0x10000];
	std::unique_ptr<uint8_t[]> code;
	size_t code_size = 0;
	l65_read_fn rd = nullptr;
	l65_write_fn wr = nullptr;
	int fault = 0;
	char fault_msg[128] = {0};
	uint32_t pc_now = 0;

	void set_fault(const char *what, uint32_t addr)
	{
		if (fault)
			return;
		fault = 1;
		snprintf(fault_msg, sizeof fault_msg, "%s $%02X:%04X at PC $%02X:%04X",
			 what, (unsigned)(addr >> 16), (unsigned)(addr & 0xFFFF),
			 (unsigned)(pc_now >> 16), (unsigned)(pc_now & 0xFFFF));
	}

	uint8_t read(uint32_t address) override
	{
		uint32_t bank = address >> 16;
		uint16_t off = (uint16_t)address;
		if (bank == 0)
			return bank0[off];
		if (bank == L65_GAME_BANK) {
			int f = 0;
			uint8_t v = rd(off, &f);
			if (f)
				set_fault("bad game-bank read", address);
			return v;
		}
		if (bank == L65_CODE_BANK)
			return off < code_size ? code[off] : 0;
		set_fault("read outside the map", address);
		return 0;
	}

	void write(uint32_t address, uint8_t value) override
	{
		uint32_t bank = address >> 16;
		uint16_t off = (uint16_t)address;
		if (bank == 0) {
			bank0[off] = value;
			return;
		}
		if (bank == L65_GAME_BANK) {
			int f = 0;
			wr(off, value, &f);
			if (f)
				set_fault("bad game-bank write", address);
			return;
		}
		set_fault("write outside the map", address);
	}
};

struct Machine {
	NClock clock;
	std::unique_ptr<cpu_state> cpu;
	std::unique_ptr<LowerMMU> mmu;
	int returned = 0;
	int failed = 0;
	uint8_t fail_reason = 0;
	uint16_t fail_detail = 0;
	FILE *trace = nullptr;
};

Machine *g_m = nullptr;

void on_return(cpu_state *, void *ctx)
{
	static_cast<Machine *>(ctx)->returned = 1;
}

void on_fail(cpu_state *cpu, void *ctx)
{
	Machine *m = static_cast<Machine *>(ctx);
	m->failed = 1;
	m->fail_reason = cpu->a_lo;
	m->fail_detail = cpu->x;
}

void on_fault(cpu_state *, void *ctx)
{
	Machine *m = static_cast<Machine *>(ctx);
	m->mmu->set_fault("BRK or COP", m->mmu->pc_now);
	m->returned = 1;
}

void trace_line(Machine *m)
{
	cpu_state *c = m->cpu.get();
	uint32_t pc = ((uint32_t)c->pb << 16) | c->pc;
	uint8_t op = m->mmu->read(pc);
	uint8_t b1 = m->mmu->read(pc + 1), b2 = m->mmu->read(pc + 2),
		b3 = m->mmu->read(pc + 3);
	fprintf(m->trace,
		"%10llu %02X:%04X %02X %02X %02X %02X %s  A=%04X X=%04X Y=%04X S=%04X D=%04X DB=%02X P=%02X%s\n",
		(unsigned long long)m->clock.get_cycles(), c->pb, c->pc, op, b1, b2, b3,
		k_mnem[op], c->a, c->x, c->y, c->sp, c->d, c->db, c->p,
		c->E ? " E" : "");
}

} // namespace

extern "C" int l65_init(const char *bin_path)
{
	FILE *f = fopen(bin_path, "rb");
	if (!f) {
		fprintf(stderr, "lower: cannot open %s\n", bin_path);
		return -1;
	}
	g_m = new Machine;
	g_m->mmu = std::make_unique<LowerMMU>();
	LowerMMU *mmu = g_m->mmu.get();
	memset(mmu->bank0, 0, sizeof mmu->bank0);
	mmu->code = std::make_unique<uint8_t[]>(0x10000);
	memset(mmu->code.get(), 0, 0x10000);
	mmu->code_size = fread(mmu->code.get(), 1, 0x10000, f);
	fclose(f);

	/* BRK and COP land on a fault trap. */
	mmu->bank0[FAULT_STUB] = 0x42;
	mmu->bank0[FAULT_STUB + 1] = WDM_FAULT;
	for (uint16_t v : {(uint16_t)N_BRK_VECTOR, (uint16_t)N_COP_VECTOR,
			   (uint16_t)BRK_VECTOR, (uint16_t)COP_VECTOR}) {
		mmu->bank0[v] = (uint8_t)FAULT_STUB;
		mmu->bank0[v + 1] = (uint8_t)(FAULT_STUB >> 8);
	}

	g_m->cpu = std::make_unique<cpu_state>(PROCESSOR_65816);
	cpu_state *cpu = g_m->cpu.get();
	cpu->trace = false;
	cpu->set_mmu(mmu);
	cpu->cpun = create65816(&g_m->clock);
	cpu->core = cpu->cpun.get();
	cpu->set_wdm_handler(L65_WDM_RETURN, {on_return, g_m});
	cpu->set_wdm_handler(L65_WDM_FAIL, {on_fail, g_m});
	cpu->set_wdm_handler(WDM_FAULT, {on_fault, g_m});
	return 0;
}

extern "C" void l65_set_bus(l65_read_fn rd, l65_write_fn wr)
{
	g_m->mmu->rd = rd;
	g_m->mmu->wr = wr;
}

extern "C" void l65_poke_dp(uint8_t off, uint8_t value)
{
	g_m->mmu->bank0[off] = value;
}

extern "C" uint8_t l65_peek_dp(uint8_t off)
{
	return g_m->mmu->bank0[off];
}

extern "C" uint64_t l65_cycles(void)
{
	return g_m->clock.get_cycles();
}

extern "C" void l65_trace(FILE *f)
{
	g_m->trace = f;
}

extern "C" int l65_failed(uint8_t *reason, uint16_t *detail)
{
	if (reason)
		*reason = g_m->fail_reason;
	if (detail)
		*detail = g_m->fail_detail;
	return g_m->failed;
}

extern "C" int l65_call(unsigned n, L65Regs *regs, char *err, size_t cap)
{
	Machine *m = g_m;
	LowerMMU *mmu = m->mmu.get();
	cpu_state *cpu = m->cpu.get();
	uint32_t target = (L65_CODE_BANK << 16) | (uint32_t)(4u * n);

	/* JSL target ; WDM $01 */
	uint8_t *s = &mmu->bank0[L65_STUB];
	s[0] = 0x22;
	s[1] = (uint8_t)target;
	s[2] = (uint8_t)(target >> 8);
	s[3] = (uint8_t)(target >> 16);
	s[4] = 0x42;
	s[5] = L65_WDM_RETURN;

	cpu->E = 0;
	cpu->p = 0;
	cpu->_M = 1;
	cpu->_X = 0;
	cpu->I = 1;
	cpu->halt = 0;
	cpu->_reset_pending = false;
	cpu->irq_asserted = false;
	cpu->irq_pipe = 0;
	cpu->d = 0;
	cpu->db = L65_GAME_BANK;
	cpu->pb = 0;
	cpu->pc = L65_STUB;
	cpu->sp = L65_STACK_TOP;
	cpu->a = regs->a;
	cpu->x = regs->x;
	cpu->y = regs->y;

	m->returned = 0;
	m->failed = 0;
	mmu->fault = 0;
	mmu->fault_msg[0] = 0;

	unsigned long n_insn = 0;
	while (!m->returned && !mmu->fault) {
		mmu->pc_now = ((uint32_t)cpu->pb << 16) | cpu->pc;
		if (m->trace)
			trace_line(m);
		cpu->cpun->execute_next(cpu);
		if (++n_insn > MAX_INSNS) {
			snprintf(err, cap, "runaway: %lu instructions, PC $%02X:%04X",
				 n_insn, cpu->pb, cpu->pc);
			return -1;
		}
	}
	regs->a = cpu->a;
	regs->x = cpu->x;
	regs->y = cpu->y;
	if (mmu->fault) {
		snprintf(err, cap, "%s", mmu->fault_msg);
		return -1;
	}
	if (cpu->E || !cpu->_M || cpu->_X || cpu->d != 0 ||
	    cpu->db != L65_GAME_BANK || cpu->sp != L65_STACK_TOP || cpu->D) {
		snprintf(err, cap,
			 "bad exit state: E=%u M=%u X=%u D=%u DP=%04X DB=%02X S=%04X",
			 (unsigned)cpu->E, (unsigned)cpu->_M, (unsigned)cpu->_X,
			 (unsigned)cpu->D, cpu->d, cpu->db, cpu->sp);
		return -1;
	}
	return 0;
}
