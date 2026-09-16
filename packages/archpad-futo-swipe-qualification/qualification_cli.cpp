#include <cmath>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <limits>
#include <string>
#include <vector>

#include <nlohmann/json.hpp>

#include "swipe_decoder/engine.hpp"
#include "swipe_decoder/layout.hpp"
#include "swipe_decoder/trie.hpp"

using json = nlohmann::json;

namespace {

struct Options {
    std::string assets = "/usr/share/archpad-futo-swipe-qualification";
    std::string trace;
    int beam_width = 100;
    int top_k = 4;
    int threads = 1;
};

void usage(const char* name) {
    std::cerr << "Usage: " << name
              << " --trace FILE|- [--assets DIR] [--top-k N]"
              << " [--beam-width N] [--threads N]\n";
}

bool parse_positive(const char* text, int& value) {
    char* end = nullptr;
    long parsed = std::strtol(text, &end, 10);
    if (end == text || *end != '\0' || parsed < 1 ||
        parsed > std::numeric_limits<int>::max()) {
        return false;
    }
    value = static_cast<int>(parsed);
    return true;
}

bool parse_options(int argc, char** argv, Options& options) {
    for (int i = 1; i < argc; ++i) {
        const std::string arg = argv[i];
        if (arg == "--help" || arg == "-h") {
            usage(argv[0]);
            std::exit(0);
        }
        if (i + 1 >= argc) {
            std::cerr << "Missing value for " << arg << "\n";
            return false;
        }
        const char* value = argv[++i];
        if (arg == "--assets") options.assets = value;
        else if (arg == "--trace") options.trace = value;
        else if (arg == "--top-k") {
            if (!parse_positive(value, options.top_k)) return false;
        } else if (arg == "--beam-width") {
            if (!parse_positive(value, options.beam_width)) return false;
        } else if (arg == "--threads") {
            if (!parse_positive(value, options.threads)) return false;
        } else {
            std::cerr << "Unknown option: " << arg << "\n";
            return false;
        }
    }
    return !options.trace.empty();
}

json read_trace(const std::string& path) {
    if (path == "-") return json::parse(std::cin);
    std::ifstream stream(path);
    if (!stream) throw std::runtime_error("cannot open trace: " + path);
    return json::parse(stream);
}

void parse_trace(const json& input, std::vector<float>& x,
                 std::vector<float>& y, std::vector<float>& t,
                 std::vector<std::string>& context) {
    if (!input.contains("points") || !input.at("points").is_array()) {
        throw std::runtime_error("trace must contain a points array");
    }
    const auto& points = input.at("points");
    if (points.size() < 2) {
        throw std::runtime_error("trace must contain at least two points");
    }

    float previous_t = -1.0f;
    for (const auto& point : points) {
        if (!point.is_object() || !point.contains("x") ||
            !point.contains("y") || !point.contains("t")) {
            throw std::runtime_error("each point must contain x, y, and t");
        }
        const float px = point.at("x").get<float>();
        const float py = point.at("y").get<float>();
        const float pt = point.at("t").get<float>();
        if (!std::isfinite(px) || !std::isfinite(py) || !std::isfinite(pt)) {
            throw std::runtime_error("point values must be finite");
        }
        if (px < 0.0f || px > 1.0f || py < 0.0f || py > 1.0f) {
            throw std::runtime_error("x and y must be normalized to 0.0..1.0");
        }
        if (pt < 0.0f || pt < previous_t) {
            throw std::runtime_error("timestamps must be non-negative and monotonic");
        }
        x.push_back(px);
        y.push_back(py);
        t.push_back(pt);
        previous_t = pt;
    }

    if (input.contains("context")) {
        if (!input.at("context").is_array()) {
            throw std::runtime_error("context must be an array of strings");
        }
        context = input.at("context").get<std::vector<std::string>>();
    }
}

std::string asset(const Options& options, const std::string& relative) {
    return options.assets + "/" + relative;
}

}  // namespace

int main(int argc, char** argv) {
    Options options;
    if (!parse_options(argc, argv, options)) {
        usage(argv[0]);
        return 2;
    }

    try {
        std::vector<float> x, y, t;
        std::vector<std::string> context;
        parse_trace(read_trace(options.trace), x, y, t, context);

        auto trie_optional = swipe_decoder::load_trie_simple(
            asset(options, "vocabs/en.combined"));
        if (!trie_optional) {
            throw std::runtime_error("failed to load English vocabulary");
        }
        auto trie = std::move(*trie_optional);

        swipe_decoder::KeyboardLayout layout;
        if (!swipe_decoder::load_layout_json(
                asset(options, "layouts/en_qwerty.json"), layout)) {
            throw std::runtime_error("failed to load English QWERTY layout");
        }

        swipe_decoder::SwipeEngine::Config config;
        config.encoder_path = asset(options, "honorable_sturgeon/model_fp32.pte");
        config.decoder_path = asset(options, "magic_macaw/model_fp32.pte");
        config.lm_model_path = asset(options, "hungry_jellyfish/context_lm.pte");
        config.lm_vocab_path = asset(options, "hungry_jellyfish/vocab.txt");
        config.scoring_path = asset(options, "scoring.json");
        config.layout = std::move(layout);
        config.dictionaries = {trie.itrie()};
        config.beam_width = options.beam_width;
        config.top_k = options.top_k;
        config.num_threads = options.threads;

        swipe_decoder::SwipeEngine engine;
        if (!engine.init(config)) {
            throw std::runtime_error("failed to initialize FUTO Swipe engine");
        }

        const auto candidates = engine.recognize(
            x.data(), y.data(), t.data(), x.size(), context,
            options.top_k, options.beam_width);
        const auto& timing = engine.last_timing();

        json output;
        output["candidates"] = json::array();
        for (const auto& candidate : candidates) {
            output["candidates"].push_back({
                {"word", candidate.word},
                {"score", candidate.final_score},
                {"ctc_score", candidate.ctc_score},
                {"frequency_score", candidate.freq_score},
                {"lm_score", candidate.lm_score}
            });
        }
        output["timing_us"] = {
            {"resample", timing.resample_us},
            {"encoder", timing.encoder_us},
            {"decoder", timing.decoder_us},
            {"beam", timing.beam_us},
            {"language_model", timing.lm_us},
            {"total", timing.total_us}
        };
        output["models"] = {
            {"decoder", engine.hasDecoder()},
            {"context_lm", engine.hasLm()}
        };
        std::cout << output.dump(2) << '\n';
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "archpad-futo-swipe-qualify: " << error.what() << '\n';
        return 1;
    }
}
