#pragma once

#include <string>
#include <unordered_map>

namespace musip::dqm {

/** @brief A class to hold optional string values representing preset metadata.
 *
 * Instances can be chained up, so that if a value is not set then the value from the "parent"
 * is returned instead.
 *
 * Note that if you do chain instances up, it's all done on raw pointers. So you are responsible
 * that all instances lower down the chain have a lifetime longer than those higher up. For
 * example, the following code will segfault (if you're lucky, or random behaviour if you're not):
 *
 * @code
 * Metadata createWithParent() {
 *     Metadata parent;
 *     parent.set<Category::AxisTitleX>("x axis title from parent");
 *
 *     Metadata child(&parent);
 *     child.set<Category::Title>("title directly on child");
 *
 *     return child; // Child is copy/move constructed, but parent is not. Parent will be out of scope after this line.
 * }
 *
 * void someFunction() {
 *     Metadata badInstance = createWithParent();
 *     printf("Title is %s\n", badInstance.get<Category::Title>().c_str());  // Technically okay, since it comes from the child
 *     printf("AxisTitleX is %s\n", badInstance.get<Category::AxisTitleX>().c_str());  // Segfault, refers to parent which is no longer in scope
 * }
 * @endcode
 * */
class Metadata {
public:
    enum class Category { Title, Description, AxisTitleX, AxisTitleY, AxisTitleZ };

    /** @brief Tag structs to help with constructing Metadata instances.
     *
     * Required so that constructor parameters can differentiate which category is being specified. These will
     * most likely only ever be used as parameters for the Metadata constructor. */
    template<Category category_> struct CategoryTag {
        std::string value;
        static constexpr Category category = category_;
        template<typename string_type>
        CategoryTag(string_type&& value_) : value(std::forward<string_type>(value_)) {}
    };
    struct Title       : public CategoryTag<Category::Title>       {template<typename string_type> explicit Title      (string_type&& value) : CategoryTag(std::forward<string_type>(value)) {}};
    struct Description : public CategoryTag<Category::Description> {template<typename string_type> explicit Description(string_type&& value) : CategoryTag(std::forward<string_type>(value)) {}};
    struct AxisTitleX  : public CategoryTag<Category::AxisTitleX>  {template<typename string_type> explicit AxisTitleX (string_type&& value) : CategoryTag(std::forward<string_type>(value)) {}};
    struct AxisTitleY  : public CategoryTag<Category::AxisTitleY>  {template<typename string_type> explicit AxisTitleY (string_type&& value) : CategoryTag(std::forward<string_type>(value)) {}};
    struct AxisTitleZ  : public CategoryTag<Category::AxisTitleZ>  {template<typename string_type> explicit AxisTitleZ (string_type&& value) : CategoryTag(std::forward<string_type>(value)) {}};

    /** @brief Constructor optionally setting a parent in the chain, but no entries. */
    Metadata(const Metadata* pNextInChain = nullptr) : pNextInChain_(pNextInChain) {}

    /** @brief Constructor setting a parent in the chain, and one or more entries where the first is an rvalue. */
    template<Category first_category, typename... other_tags>
    Metadata(const Metadata* pNextInChain, CategoryTag<first_category>&& firstTag, other_tags... otherTags);

    /** @brief Constructor setting a parent in the chain, and one or more entries where the first is an lvalue.
     *
     * Functionally exactly like the previous constructor, but this boiler plate is required to differentiate between
     * lvalue and rvalue parameters. */
    template<Category first_category, typename... other_tags>
    Metadata(const Metadata* pNextInChain, const CategoryTag<first_category>& firstTag, other_tags... otherTags);

    /** @brief Constructor with no parent in the chain but one or more entries, where the first is an rvalue. */
    template<Category first_category, typename... other_tags>
    Metadata(CategoryTag<first_category>&& firstTag, other_tags... otherTags);

    /** @brief Constructor with no parent in the chain but one or more entries, where the first is an lvalue. */
    template<Category first_category, typename... other_tags>
    Metadata(const CategoryTag<first_category>& firstTag, other_tags... otherTags);

    /** @brief Returns the value for the category specified by the template parameter.
     *
     * If the entry is unset in anything in the chain, a reference to `nullEntry` is returned. */
    template<Category category>
    const std::string& get() const;

    /** @brief Returns true if anything in the chain has had this parameter set. */
    template<Category category>
    bool has() const;

    /** @brief Set the value of the specified category on this instance only.
     *
     * The chain is never traversed when setting values. */
    template<Category category, typename string_type>
    void set(string_type&& value);

    /** @brief Allows setting multiple values at once. The category of each one is specified by wrapping the value in the relevant subclass of CategoryTag. */
    template<Category category, typename... other_tag_types>
    void set(CategoryTag<category>&& firstTag, other_tag_types&&... otherTags);

    template<Category category, typename... other_tag_types>
    void set(const CategoryTag<category>& firstTag, other_tag_types&&... otherTags);

    /** @brief The constant reference used to indicate a category has not been set. */
    static const std::string nullEntry;
protected:
    // We hand out references to objects in this collection. From https://en.cppreference.com/w/cpp/container/unordered_map
    // unordered_map has the property "...pointers to either key or data stored in the container are only invalidated by
    // erasing that element, even when the corresponding iterator is invalidated". Pretty sure std::map doesn't have this
    // property, so we can only use unordered_map.
    std::unordered_map<Category,std::string> entries_;
    const Metadata* pNextInChain_ = nullptr;
}; // end of class Metadata

} // end of namespace musip::dqm

//
// Templated methods that are required to be in the header file.
//

template<musip::dqm::Metadata::Category first_category, typename... other_tags>
musip::dqm::Metadata::Metadata(const Metadata* pNextInChain, CategoryTag<first_category>&& firstTag, other_tags... otherTags)
    : pNextInChain_(pNextInChain) {
    set(std::move(firstTag), std::forward<other_tags>(otherTags)...);
}

template<musip::dqm::Metadata::Category first_category, typename... other_tags>
musip::dqm::Metadata::Metadata(const Metadata* pNextInChain, const CategoryTag<first_category>& firstTag, other_tags... otherTags)
    : pNextInChain_(pNextInChain) {
    set(firstTag, std::forward<other_tags>(otherTags)...);
}

template<musip::dqm::Metadata::Category first_category, typename... other_tags>
musip::dqm::Metadata::Metadata(CategoryTag<first_category>&& firstTag, other_tags... otherTags)
    : pNextInChain_(nullptr) {
    set(std::move(firstTag), std::forward<other_tags>(otherTags)...);
}

template<musip::dqm::Metadata::Category first_category, typename... other_tags>
musip::dqm::Metadata::Metadata(const CategoryTag<first_category>& firstTag, other_tags... otherTags)
    : pNextInChain_(nullptr) {
    set(firstTag, std::forward<other_tags>(otherTags)...);
}

template<musip::dqm::Metadata::Category category>
const std::string& musip::dqm::Metadata::get() const {
    if(const auto iFindResult = entries_.find(category); iFindResult != entries_.end() ) {
        return iFindResult->second;
    }
    else if(pNextInChain_ != nullptr) return pNextInChain_->get<category>();
    else return nullEntry;
}

template<musip::dqm::Metadata::Category category>
bool musip::dqm::Metadata::has() const {
    if(entries_.find(category) != entries_.end()) return true;
    else if(pNextInChain_ != nullptr) return pNextInChain_->has<category>();
    else return false;
}

template<musip::dqm::Metadata::Category category, typename string_type>
void musip::dqm::Metadata::set(string_type&& value) {
    entries_.insert_or_assign(category, std::forward<string_type>(value));
}

template<musip::dqm::Metadata::Category category, typename... other_tag_types>
void musip::dqm::Metadata::set(CategoryTag<category>&& firstTag, other_tag_types&&... otherTags) {
    entries_.insert_or_assign(category, std::move(firstTag.value));
    if constexpr(sizeof...(other_tag_types) > 0) set(std::forward<other_tag_types>(otherTags)...);
}

template<musip::dqm::Metadata::Category category, typename... other_tag_types>
void musip::dqm::Metadata::set(const CategoryTag<category>& firstTag, other_tag_types&&... otherTags) {
    entries_.insert_or_assign(category, firstTag.value);
    if constexpr(sizeof...(other_tag_types) > 0) set(std::forward<other_tag_types>(otherTags)...);
}
