#include "mdi.h"

#include "mdi_icons_data.h"

#include <QtCore/QByteArray>
#include <QtCore/QLoggingCategory>
#include <QtGui/QFontDatabase>

#include <algorithm>
#include <optional>

namespace {

constexpr QLatin1StringView kFontPath{
    ":/res/QtHomeAssistant/fonts/materialdesignicons-webfont.ttf"};
constexpr QLatin1StringView kPrefix{"mdi:"};

// The table is sorted by name, so a binary search is enough.
std::optional<char32_t> lookup(const QString &name) {
  const QByteArray key = name.trimmed().toLower().toLatin1();
  QByteArrayView view{key};
  if (view.startsWith(kPrefix))
    view = view.sliced(kPrefix.size());

  if (view.isEmpty())
    return std::nullopt;

  const std::string_view needle{view.constData(),
                                static_cast<size_t>(view.size())};
  const auto it = std::ranges::lower_bound(mdi::kIcons, needle, {},
                                           &mdi::Entry::name);
  if (it == mdi::kIcons.end() || it->name != needle)
    return std::nullopt;

  return it->codepoint;
}

QString toGlyph(char32_t codepoint) {
  return QString::fromUcs4(&codepoint, 1);
}

} // namespace

Mdi *Mdi::create(QQmlEngine *, QJSEngine *) { return new Mdi(); }

Mdi::Mdi(QObject *parent) : QObject(parent) {
  // Registering here rather than in main() keeps the font's lifetime tied to the
  // type that needs it, and guarantees it is loaded before any QML -- including
  // the filesystem-loaded dashboard -- can ask for a glyph.
  const int id = QFontDatabase::addApplicationFont(kFontPath);
  if (id == -1) {
    qWarning() << "Mdi: failed to load the icon font from" << kFontPath
               << "- icons will render as tofu";
    return;
  }

  const QStringList families = QFontDatabase::applicationFontFamilies(id);
  if (families.isEmpty()) {
    qWarning() << "Mdi:" << kFontPath << "registered but exposed no family";
    return;
  }

  font_family_ = families.constFirst();
}

QString Mdi::version() const {
  return QString::fromUtf8(mdi::kVersion.data(),
                           static_cast<qsizetype>(mdi::kVersion.size()));
}

QString Mdi::glyph(const QString &name) const {
  if (name.trimmed().isEmpty())
    return {};

  if (const std::optional<char32_t> codepoint = lookup(name))
    return toGlyph(*codepoint);

  // Bindings re-evaluate, so warn once per name rather than on every pass.
  if (!warned_names_.contains(name)) {
    warned_names_.insert(name);
    qWarning() << "Mdi: unknown icon" << name << "- not in MDI" << version();
  }
  return toGlyph(mdi::kFallbackCodepoint);
}

bool Mdi::hasIcon(const QString &name) const {
  return lookup(name).has_value();
}
