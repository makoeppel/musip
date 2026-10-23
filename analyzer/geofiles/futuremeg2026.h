// geometry.h - chip (chipid, col, row)  ->  (layer, global col, global row, x/y/z in mm)
//
// Coordinate conventions
// ----------------------
// Quad-local pixel frame (exactly as in the hand sketch, quad drawn as seen from the source):
//
//        qc = 0 ..... 255 | 256 ..... 511
//   qr=499  +-------------+-------------+
//           |   chip 3    |   chip 2    |   chips 2,3 are rotated by 180 deg:
//           | (0/0 = top  | (0/0 = top  |   origin at their top-right corner,
//           |   right)    |   right)    |   col runs to -qc, row runs to -qr
//   qr=250  +-------------+-------------+
//   qr=249  |   chip 1    |   chip 0    |   chips 0,1: origin at bottom-left,
//           | (0/0 = bot. | (0/0 = bot. |   col runs to +qc, row runs to +qr
//           |    left)    |    left)    |
//   qr=0    +-------------+-------------+
//
//   local chip k of layer L has the hardware chip id  Layer::chip[k]
//   (default: L0 = 8..11, L1 = 4..7, L2 = 0..3).
//
// Global (telescope) frame: x to the right, y up, as seen FROM THE SOURCE looking
// downstream through L0 -> L1 -> L2 (same view as the sketch), z along the beam.
// Each layer has a discrete orientation `op` (one of the 8 symmetries of the square,
// found from the Sr90 scan) plus a fine alignment (dx, dy, rot) relative to L0.
//
//   op = 4*mirror + nrot :  first  u -> -u  if mirror,  then rotate nrot x 90 deg CCW.
//   e.g. op 0 = as drawn, op 2 = rotated 180 deg in-plane, op 4 = mirrored (module
//   turned around about the vertical axis -> back side facing the source).
#ifndef QUADTEL_GEOMETRY_H
#define QUADTEL_GEOMETRY_H

#include <array>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

namespace quadtel {

constexpr int    NCOL = 256, NROW = 250;          // per chip
constexpr int    QCOL = 2 * NCOL, QROW = 2 * NROW; // per quad (512 x 500)
constexpr int    MAXCHIP = 32;                     // chipid is 5 bit

struct GlobalPixel {
    bool   valid = false;
    int    layer = -1;
    int    local_chip = -1;   // 0..3 position in the quad (sketch numbering)
    int    qcol = -1, qrow = -1; // quad-local pixel indices (sketch frame, before orientation)
    int    gcol = -1, grow = -1; // global pixel indices after orientation -> use for hitmaps
    double x = 0, y = 0, z = 0;  // aligned position in mm (quad centre of L0 = 0,0)
};

struct Layer {
    std::array<int, 4> chip{ {0, 1, 2, 3} };  // hardware chip id of local chip 0..3
    int    op  = 0;      // discrete orientation, 0..7
    double dx  = 0;      // mm, after orientation
    double dy  = 0;      // mm
    double rot = 0;      // rad, small in-plane rotation about the quad centre
    double z   = 0;      // mm
    // integer global-grid size (90 deg ops swap the axes)
    int nx() const { return (op % 2) ? QROW : QCOL; }
    int ny() const { return (op % 2) ? QCOL : QROW; }
};

// --- quad-local mapping from the sketch -------------------------------------------
inline void chip_to_quad(int local_chip, int col, int row, int& qc, int& qr) {
    switch (local_chip) {
        case 0: qc = NCOL + col;         qr = row;             break; // bottom right
        case 1: qc = col;                qr = row;             break; // bottom left
        case 2: qc = QCOL - 1 - col;     qr = QROW - 1 - row;  break; // top right, 180 deg
        case 3: qc = NCOL - 1 - col;     qr = QROW - 1 - row;  break; // top left, 180 deg
        default: qc = qr = -1;
    }
}

// apply D4 operation to centred coordinates (u,v)
inline void apply_op(int op, double& u, double& v) {
    if (op >= 4) u = -u;
    for (int k = 0; k < (op & 3); ++k) { double t = u; u = -v; v = t; }
}
inline void apply_op_inverse(int op, double& u, double& v) {
    for (int k = 0; k < (op & 3); ++k) { double t = u; u = v; v = -t; }
    if (op >= 4) u = -u;
}

class Geometry {
public:
    double pitch_mm = 0.080;   // MuPix11: 80 um x 80 um
    double gap_mm   = 0.0;     // extra dead gap between the chips of a quad (if known)
    std::vector<Layer> layers;

    Geometry() {
        // default: chip ids from the setup description, z positions only indicative
        layers.resize(3);
        layers[0].chip = {8, 9, 10, 11};  layers[0].z = 0;
        layers[1].chip = {4, 5, 6, 7};    layers[1].z = 30;
        layers[2].chip = {0, 1, 2, 3};    layers[2].z = 60;
        // orientations found from Sr90 run 342 (frame seen from the source); offsets from
        // run 342 are only good to ~1 mm, load geometry_aligned.txt to use them
        layers[0].op = 4;
        layers[1].op = 2;
        layers[2].op = 4;
        rebuild();
    }

    void rebuild() {
        lut_layer_.fill(-1); lut_local_.fill(-1);
        for (int l = 0; l < (int)layers.size(); ++l)
            for (int k = 0; k < 4; ++k) {
                int c = layers[l].chip[k];
                if (c >= 0 && c < MAXCHIP) { lut_layer_[c] = l; lut_local_[c] = k; }
            }
    }

    int layer_of_chip(int chipid) const { return (chipid >= 0 && chipid < MAXCHIP) ? lut_layer_[chipid] : -1; }

    // quad-local position in mm (centred, includes the optional inter-chip gap)
    void quad_mm(int qc, int qr, double& u, double& v) const {
        u = (qc - (QCOL - 1) * 0.5) * pitch_mm + (qc >= NCOL ? 0.5 : -0.5) * gap_mm;
        v = (qr - (QROW - 1) * 0.5) * pitch_mm + (qr >= NROW ? 0.5 : -0.5) * gap_mm;
    }

    // >>> THE mapping function: (chipid, col, row) -> layer, global col/row, x/y/z <<<
    GlobalPixel map(int chipid, int col, int row) const {
        GlobalPixel g;
        if (chipid < 0 || chipid >= MAXCHIP || col < 0 || col >= NCOL || row < 0 || row >= NROW) return g;
        const int l = lut_layer_[chipid];
        if (l < 0) return g;
        const Layer& L = layers[l];
        g.layer = l; g.local_chip = lut_local_[chipid];
        chip_to_quad(g.local_chip, col, row, g.qcol, g.qrow);
        // integer global indices (orientation only, no fine alignment)
        double u = g.qcol - (QCOL - 1) * 0.5, v = g.qrow - (QROW - 1) * 0.5;
        apply_op(L.op, u, v);
        g.gcol = (int)std::lround(u + (L.nx() - 1) * 0.5);
        g.grow = (int)std::lround(v + (L.ny() - 1) * 0.5);
        // aligned mm position
        double um, vm; quad_mm(g.qcol, g.qrow, um, vm);
        apply_op(L.op, um, vm);
        const double c = std::cos(L.rot), s = std::sin(L.rot);
        g.x = c * um - s * vm + L.dx;
        g.y = s * um + c * vm + L.dy;
        g.z = L.z;
        g.valid = true;
        return g;
    }

    // fast integer-only variant (no trig): layer, global col, global row. Returns false if unmapped.
    bool map_pixel(int chipid, int col, int row, int& layer, int& gcol, int& grow) const {
        if (chipid < 0 || chipid >= MAXCHIP || col < 0 || col >= NCOL || row < 0 || row >= NROW) return false;
        layer = lut_layer_[chipid];
        if (layer < 0) return false;
        const Layer& L = layers[layer];
        int qc, qr; chip_to_quad(lut_local_[chipid], col, row, qc, qr);
        // work in doubled coordinates so the centre (255.5, 249.5) is an integer
        int u = 2 * qc - (QCOL - 1), v = 2 * qr - (QROW - 1);
        if (L.op >= 4) u = -u;
        for (int k = 0; k < (L.op & 3); ++k) { int t = u; u = -v; v = t; }
        gcol = (u + L.nx() - 1) / 2;
        grow = (v + L.ny() - 1) / 2;
        return true;
    }

    // --- persistence -------------------------------------------------------------
    // text format, one line per layer:
    //   layer <id> chips <c0> <c1> <c2> <c3> op <op> dx <mm> dy <mm> rot <rad> z <mm>
    bool save(const std::string& fn) const {
        std::ofstream o(fn);
        if (!o) return false;
        o << "# quad telescope geometry  (pitch_mm, gap_mm, then one line per layer)\n";
        o << "# op = 4*mirror + nrot90 (see geometry.h); dx/dy in mm, rot in rad, frame: seen from the source\n";
        o << "pitch_mm " << pitch_mm << "\ngap_mm " << gap_mm << "\n";
        char buf[256];
        for (size_t l = 0; l < layers.size(); ++l) {
            const Layer& L = layers[l];
            std::snprintf(buf, sizeof buf, "layer %zu chips %d %d %d %d op %d dx %.4f dy %.4f rot %.6f z %.2f\n",
                          l, L.chip[0], L.chip[1], L.chip[2], L.chip[3], L.op, L.dx, L.dy, L.rot, L.z);
            o << buf;
        }
        return true;
    }
    bool load(const std::string& fn) {
        std::ifstream in(fn);
        if (!in) return false;
        std::vector<Layer> ls;
        std::string line;
        while (std::getline(in, line)) {
            if (line.empty() || line[0] == '#') continue;
            std::istringstream ss(line);
            std::string key; ss >> key;
            if (key == "pitch_mm") ss >> pitch_mm;
            else if (key == "gap_mm") ss >> gap_mm;
            else if (key == "layer") {
                Layer L; int id; std::string k;
                ss >> id;
                while (ss >> k) {
                    if (k == "chips") ss >> L.chip[0] >> L.chip[1] >> L.chip[2] >> L.chip[3];
                    else if (k == "op") ss >> L.op;
                    else if (k == "dx") ss >> L.dx;
                    else if (k == "dy") ss >> L.dy;
                    else if (k == "rot") ss >> L.rot;
                    else if (k == "z") ss >> L.z;
                }
                if (id >= (int)ls.size()) ls.resize(id + 1);
                ls[id] = L;
            }
        }
        if (ls.empty()) return false;
        layers = ls; rebuild();
        return true;
    }

private:
    std::array<int, MAXCHIP> lut_layer_{}, lut_local_{};
};

} // namespace quadtel
#endif