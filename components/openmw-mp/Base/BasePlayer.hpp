#ifndef OPENMW_BASEPLAYER_HPP
#define OPENMW_BASEPLAYER_HPP

#include <cmath>
#include <cstdint>
#include <string>
#include <vector>

#include <components/esm3/loadcell.hpp>
#include <components/esm3/loadcrea.hpp>
#include <components/esm3/loadnpc.hpp>
#include <components/esm3/npcstats.hpp>
#include <components/esm3/creaturestats.hpp>
#include <components/esm3/loadclas.hpp>
#include <components/esm3/loadspel.hpp>

#include <components/openmw-mp/Base/BaseStructs.hpp>
#include <components/openmw-mp/Base/Sequence.hpp>

#include <components/openmw-mp/Transport/PacketIdentity.hpp>

namespace mwmp
{
    inline bool isNewerPlayerPositionSequence(std::uint32_t incoming, std::uint32_t current)
    {
        return isNewerSequence(incoming, current);
    }

    inline bool isPlayerPositionSequenceAtLeast(std::uint32_t incoming, std::uint32_t minimum)
    {
        return incoming == minimum || isNewerPlayerPositionSequence(incoming, minimum);
    }

    inline bool isNewerPlayerAnimFlagsSequence(std::uint32_t incoming, std::uint32_t current)
    {
        return isNewerSequence(incoming, current);
    }

    inline bool isNewerPlayerStatsDynamicSequence(std::uint32_t incoming, std::uint32_t current)
    {
        return isNewerSequence(incoming, current);
    }

    inline bool isNewerPlayerInventorySequence(std::uint32_t incoming, std::uint32_t current)
    {
        return isNewerSequence(incoming, current);
    }

    inline bool isNewerPlayerEquipmentSequence(std::uint32_t incoming, std::uint32_t current)
    {
        return isNewerSequence(incoming, current);
    }

    inline bool isNewerPlayerCombatSequence(std::uint32_t incoming, std::uint32_t current)
    {
        return isNewerSequence(incoming, current);
    }

    inline bool isFinitePlayerPosition(const ESM::Position& position)
    {
        return std::isfinite(position.pos[0]) && std::isfinite(position.pos[1]) && std::isfinite(position.pos[2])
            && std::isfinite(position.rot[0]) && std::isfinite(position.rot[1]) && std::isfinite(position.rot[2]);
    }

    struct CurrentContainer
    {
        std::string refId;
        unsigned int refNum = 0;
        unsigned int mpNum = 0;
        bool loot = false;
    };

    struct JournalItem
    {
        std::string quest;
        int index = 0;
        enum JOURNAL_ITEM_TYPE
        {
            ENTRY = 0,
            INDEX = 1,
            FINISHED = 2
        };

        std::string actorRefId;

        bool hasTimestamp = false;
        mwmp::Time timestamp;
        bool isFinished = false;

        int type = ENTRY; // 0 - An entire entry, 1 - An index, 2 - Finished state
    };

    struct Faction
    {
        std::string factionId;
        int rank;
        int reputation;
        bool isExpelled;
    };

    struct Topic
    {
        std::string topicId;
    };

    struct Book
    {
        std::string bookId;
    };

    struct QuickKey
    {
        std::string itemId;

        enum QUICKKEY_TYPE
        {   
            ITEM = 0,
            MAGIC = 1,
            ITEM_MAGIC = 2,
            UNASSIGNED = 3
        };

        unsigned short slot;
        int type;
    };

    struct CellState
    {
        ESM::Cell cell;

        enum CELL_STATE_ACTION
        {
            LOAD = 0,
            UNLOAD = 1
        };

        int type; // 0 - Cell load, 1 - Cell unload
    };

    constexpr std::uint16_t clientLuaEventSchemaVersion = 1;
    constexpr std::size_t clientLuaEventMaxNamespaceLength = 64;
    constexpr std::size_t clientLuaEventMaxNameLength = 64;
    constexpr std::size_t clientLuaEventMaxPayloadLength = 8 * 1024;

    struct ClientLuaEvent
    {
        std::uint16_t schemaVersion = clientLuaEventSchemaVersion;
        std::uint32_t sequence = 0;
        std::string namespaceName;
        std::string eventName;
        std::string payload;
    };

    struct FactionChanges
    {
        std::vector<Faction> factions;

        enum FACTION_ACTION
        {
            RANK = 0,
            EXPULSION = 1,
            REPUTATION = 2
        };

        int action; // 0 - Rank, 1 - Expulsion state, 2 - Faction reputation
    };

    struct InventoryChanges
    {
        std::vector<Item> items;
        enum ACTION_TYPE
        {
            SET = 0,
            ADD,
            REMOVE
        };
        int action; // 0 - Clear and set in entirety, 1 - Add item, 2 - Remove item
    };

    inline bool inventorySnapshotStackMatches(const Item& left, const Item& right)
    {
        return left.refId == right.refId && left.charge == right.charge
            && left.enchantmentCharge == right.enchantmentCharge && left.soul == right.soul;
    }

    inline void addInventorySnapshotItem(std::vector<Item>& snapshot, const Item& item)
    {
        if (item.refId.empty() || item.count <= 0)
            return;

        for (Item& existing : snapshot)
        {
            if (!inventorySnapshotStackMatches(existing, item))
                continue;

            existing.count += item.count;
            return;
        }

        snapshot.push_back(item);
    }

    inline void removeInventorySnapshotItem(std::vector<Item>& snapshot, const Item& item)
    {
        if (item.refId.empty() || item.count <= 0)
            return;

        for (auto it = snapshot.begin(); it != snapshot.end(); ++it)
        {
            if (!inventorySnapshotStackMatches(*it, item))
                continue;

            it->count -= item.count;
            if (it->count <= 0)
                snapshot.erase(it);
            return;
        }
    }

    inline void applyInventoryChangesToSnapshot(std::vector<Item>& snapshot, const InventoryChanges& changes)
    {
        if (changes.action == InventoryChanges::SET)
        {
            snapshot.clear();
            for (const Item& item : changes.items)
                addInventorySnapshotItem(snapshot, item);
            return;
        }

        if (changes.action == InventoryChanges::ADD)
        {
            for (const Item& item : changes.items)
                addInventorySnapshotItem(snapshot, item);
            return;
        }

        if (changes.action == InventoryChanges::REMOVE)
        {
            for (const Item& item : changes.items)
                removeInventorySnapshotItem(snapshot, item);
        }
    }

    struct SpellbookChanges
    {
        std::vector<ESM::Spell> spells;
        enum ACTION_TYPE
        {
            SET = 0,
            ADD,
            REMOVE
        };
        int action; // 0 - Clear and set in entirety, 1 - Add spell, 2 - Remove spell
    };

    inline bool spellbookSnapshotContains(const std::vector<ESM::Spell>& snapshot, const ESM::RefId& spellId)
    {
        for (const ESM::Spell& spell : snapshot)
        {
            if (spell.mId == spellId)
                return true;
        }

        return false;
    }

    inline void addSpellbookSnapshotSpell(std::vector<ESM::Spell>& snapshot, const ESM::Spell& spell)
    {
        if (spell.mId.empty() || spellbookSnapshotContains(snapshot, spell.mId))
            return;

        snapshot.push_back(spell);
    }

    inline void removeSpellbookSnapshotSpell(std::vector<ESM::Spell>& snapshot, const ESM::Spell& spell)
    {
        if (spell.mId.empty())
            return;

        for (auto it = snapshot.begin(); it != snapshot.end(); ++it)
        {
            if (it->mId != spell.mId)
                continue;

            snapshot.erase(it);
            return;
        }
    }

    inline void applySpellbookChangesToSnapshot(std::vector<ESM::Spell>& snapshot, const SpellbookChanges& changes)
    {
        if (changes.action == SpellbookChanges::SET)
        {
            snapshot.clear();
            for (const ESM::Spell& spell : changes.spells)
                addSpellbookSnapshotSpell(snapshot, spell);
            return;
        }

        if (changes.action == SpellbookChanges::ADD)
        {
            for (const ESM::Spell& spell : changes.spells)
                addSpellbookSnapshotSpell(snapshot, spell);
            return;
        }

        if (changes.action == SpellbookChanges::REMOVE)
        {
            for (const ESM::Spell& spell : changes.spells)
                removeSpellbookSnapshotSpell(snapshot, spell);
        }
    }

    enum RESURRECT_TYPE
    {
        REGULAR = 0,
        IMPERIAL_SHRINE,
        TRIBUNAL_TEMPLE
    };

    enum MISCELLANEOUS_CHANGE_TYPE
    {
        MARK_LOCATION = 0,
        SELECTED_SPELL,
        SELECTED_ENCHANTED_ITEM
    };

    enum CELL_CHANGE_REASON
    {
        CELL_CHANGE_REASON_NORMAL = 0,
        CELL_CHANGE_REASON_DOOR,
        CELL_CHANGE_REASON_MAGIC_RECALL,
        CELL_CHANGE_REASON_MAGIC_DIVINE_INTERVENTION,
        CELL_CHANGE_REASON_MAGIC_ALMSIVI_INTERVENTION,
        CELL_CHANGE_REASON_RESPAWN,
        CELL_CHANGE_REASON_GUIDED_TRAVEL,
        CELL_CHANGE_REASON_SCRIPT,
        CELL_CHANGE_REASON_JAIL,
        CELL_CHANGE_REASON_SERVER
    };

    inline bool isValidCellChangeReason(unsigned int reason)
    {
        return reason <= CELL_CHANGE_REASON_SERVER;
    }

    inline bool isExplicitCellChangeReason(unsigned int reason)
    {
        return reason != CELL_CHANGE_REASON_NORMAL && isValidCellChangeReason(reason);
    }

    class BasePlayer
    {
    public:

        struct CharGenState
        {
            int currentStage, endStage;
            bool isFinished;
        };

        struct GUIMessageBox
        {
            int id;
            int type;
            enum GUI_TYPE
            {
                MessageBox = 0,
                CustomMessageBox,
                InputDialog,
                PasswordDialog,
                ListBox
            };
            std::string label;
            std::string note;
            std::string buttons;

            std::string data;
        };

        BasePlayer(PacketGuid guid) : guid(guid)
        {
            inventoryChanges.action = 0;
            acceptedInventoryChanges.action = 0;
            spellbookChanges.action = 0;
            acceptedSpellbookChanges.action = 0;

            exchangeFullInfo = false;
            displayCreatureName = false;
            resetStats = false;
            enforcedLogLevel = -1;
        }

        BasePlayer()
        {
            inventoryChanges.action = 0;
            acceptedInventoryChanges.action = 0;
            spellbookChanges.action = 0;
            acceptedSpellbookChanges.action = 0;
        }

        bool acceptPositionPacket()
        {
            if (!hasFinitePositionPacket())
            {
                restoreAcceptedPositionPacket();
                return false;
            }

            if (hasStalePositionPacket())
            {
                restoreAcceptedPositionPacket();
                return false;
            }

            acceptedPositionSequence = positionSequence;
            acceptedPosition = position;
            acceptedDirection = direction;
            acceptedMovementSampleIntervalSeconds = sanitizeMovementSampleIntervalSeconds(movementSampleIntervalSeconds);
            movementSampleIntervalSeconds = acceptedMovementSampleIntervalSeconds;
            acceptedMovementLatencySeconds = sanitizeMovementLatencySeconds(movementLatencySeconds);
            movementLatencySeconds = acceptedMovementLatencySeconds;
            hasAcceptedPositionPacket = true;
            return true;
        }

        bool hasValidClientLuaEvent() const
        {
            return luaEvent.schemaVersion > 0 && luaEvent.schemaVersion <= clientLuaEventSchemaVersion
                && !luaEvent.namespaceName.empty()
                && luaEvent.namespaceName.size() <= clientLuaEventMaxNamespaceLength
                && !luaEvent.eventName.empty()
                && luaEvent.eventName.size() <= clientLuaEventMaxNameLength
                && luaEvent.payload.size() <= clientLuaEventMaxPayloadLength;
        }

        bool hasFinitePositionPacket() const
        {
            return isFinitePlayerPosition(position) && isFinitePlayerPosition(direction);
        }

        bool hasStalePositionPacket() const
        {
            return hasAcceptedPositionPacket
                && !isNewerPlayerPositionSequence(positionSequence, acceptedPositionSequence);
        }

        void restoreAcceptedPositionPacket()
        {
            if (!hasAcceptedPositionPacket)
                return;

            positionSequence = acceptedPositionSequence;
            position = acceptedPosition;
            direction = acceptedDirection;
            movementSampleIntervalSeconds = acceptedMovementSampleIntervalSeconds;
            movementLatencySeconds = acceptedMovementLatencySeconds;
        }

        void clearAcceptedPositionPacket()
        {
            positionSequence = 0;
            acceptedPositionSequence = 0;
            acceptedPosition = {};
            acceptedDirection = {};
            acceptedMovementSampleIntervalSeconds = 1.f / 60.f;
            acceptedMovementLatencySeconds = 0.f;
            movementSampleIntervalSeconds = acceptedMovementSampleIntervalSeconds;
            movementLatencySeconds = acceptedMovementLatencySeconds;
            hasAcceptedPositionPacket = false;
        }

        bool acceptAnimFlagsPacket()
        {
            if (hasStaleAnimFlagsPacket())
            {
                restoreAcceptedAnimFlagsPacket();
                return false;
            }

            acceptedAnimFlagsSequence = animFlagsSequence;
            acceptedMovementFlags = movementFlags;
            acceptedDrawState = drawState;
            acceptedIsJumping = isJumping;
            acceptedIsFlying = isFlying;
            acceptedHasTcl = hasTcl;
            hasAcceptedAnimFlagsPacket = true;
            return true;
        }

        bool hasStaleAnimFlagsPacket() const
        {
            return hasAcceptedAnimFlagsPacket
                && !isNewerPlayerAnimFlagsSequence(animFlagsSequence, acceptedAnimFlagsSequence);
        }

        void restoreAcceptedAnimFlagsPacket()
        {
            if (!hasAcceptedAnimFlagsPacket)
                return;

            animFlagsSequence = acceptedAnimFlagsSequence;
            movementFlags = acceptedMovementFlags;
            drawState = acceptedDrawState;
            isJumping = acceptedIsJumping;
            isFlying = acceptedIsFlying;
            hasTcl = acceptedHasTcl;
        }

        void clearAcceptedAnimFlagsPacket()
        {
            animFlagsSequence = 0;
            acceptedAnimFlagsSequence = 0;
            acceptedMovementFlags = 0;
            acceptedDrawState = 0;
            acceptedIsJumping = false;
            acceptedIsFlying = false;
            acceptedHasTcl = false;
            hasAcceptedAnimFlagsPacket = false;
        }

        void acceptCurrentInventoryPacket()
        {
            acceptedInventorySequence = inventorySequence;
            acceptedInventoryChanges = inventoryChanges;
            applyInventoryChangesToSnapshot(acceptedInventoryItems, inventoryChanges);
            hasAcceptedInventoryPacket = true;
        }

        void restoreAcceptedInventoryPacket()
        {
            inventorySequence = acceptedInventorySequence;
            if (hasAcceptedInventoryPacket)
                inventoryChanges = acceptedInventoryChanges;
            else
            {
                inventoryChanges.action = InventoryChanges::SET;
                inventoryChanges.items.clear();
            }
        }

        void clearAcceptedInventoryPacket()
        {
            inventorySequence = 0;
            acceptedInventorySequence = 0;
            acceptedInventoryChanges.action = InventoryChanges::SET;
            acceptedInventoryChanges.items.clear();
            acceptedInventoryItems.clear();
            hasAcceptedInventoryPacket = false;
        }

        void acceptCurrentSpellbookPacket()
        {
            acceptedSpellbookChanges = spellbookChanges;
            applySpellbookChangesToSnapshot(acceptedSpellbookSpells, spellbookChanges);
            hasAcceptedSpellbookPacket = true;
        }

        void clearAcceptedSpellbookPacket()
        {
            acceptedSpellbookChanges.action = SpellbookChanges::SET;
            acceptedSpellbookChanges.spells.clear();
            acceptedSpellbookSpells.clear();
            hasAcceptedSpellbookPacket = false;
        }

        bool acceptInventoryPacket()
        {
            if (hasAcceptedInventoryPacket
                && !isNewerPlayerInventorySequence(inventorySequence, acceptedInventorySequence))
            {
                restoreAcceptedInventoryPacket();
                return false;
            }

            acceptCurrentInventoryPacket();
            return true;
        }

        void acceptCurrentEquipmentPacket()
        {
            acceptedEquipmentSequence = equipmentSequence;
            for (int i = 0; i < equipmentSlotCount; ++i)
                acceptedEquipmentItems[i] = equipmentItems[i];
            hasAcceptedEquipmentPacket = true;
        }

        bool hasValidEquipmentItems() const
        {
            for (const Item& item : equipmentItems)
            {
                if (!isValidEquipmentItem(item))
                    return false;
            }

            return true;
        }

        void restoreAcceptedEquipmentPacket()
        {
            equipmentSequence = acceptedEquipmentSequence;
            for (int i = 0; i < equipmentSlotCount; ++i)
                equipmentItems[i] = hasAcceptedEquipmentPacket ? acceptedEquipmentItems[i] : Item();

            equipmentIndexChanges.clear();
        }

        void clearAcceptedEquipmentPacket()
        {
            equipmentSequence = 0;
            acceptedEquipmentSequence = 0;
            for (int i = 0; i < equipmentSlotCount; ++i)
                acceptedEquipmentItems[i] = Item();
            equipmentIndexChanges.clear();
            hasAcceptedEquipmentPacket = false;
        }

        bool acceptEquipmentPacket()
        {
            if (!hasValidEquipmentItems())
            {
                restoreAcceptedEquipmentPacket();
                return false;
            }

            if (hasAcceptedEquipmentPacket
                && !isNewerPlayerEquipmentSequence(equipmentSequence, acceptedEquipmentSequence))
            {
                if (!(exchangeFullInfo && equipmentSequence == acceptedEquipmentSequence))
                {
                    restoreAcceptedEquipmentPacket();
                    return false;
                }
            }

            acceptCurrentEquipmentPacket();
            return true;
        }

        void acceptCurrentStatsDynamicPacket()
        {
            acceptedStatsDynamicSequence = statsDynamicSequence;
            for (int i = 0; i < 3; ++i)
                acceptedStatsDynamic[i] = creatureStats.mDynamic[i];
            acceptedStatsDynamicDead = creatureStats.mDead;
            hasAcceptedStatsDynamicPacket = true;
        }

        bool hasFiniteDynamicStats() const
        {
            for (int i = 0; i < 3; ++i)
            {
                if (!std::isfinite(creatureStats.mDynamic[i].mBase)
                    || !std::isfinite(creatureStats.mDynamic[i].mCurrent)
                    || !std::isfinite(creatureStats.mDynamic[i].mMod))
                    return false;
            }

            return true;
        }

        bool hasFiniteAcceptedStatsDynamic() const
        {
            if (!hasAcceptedStatsDynamicPacket)
                return false;

            for (int i = 0; i < 3; ++i)
            {
                if (!std::isfinite(acceptedStatsDynamic[i].mBase)
                    || !std::isfinite(acceptedStatsDynamic[i].mCurrent)
                    || !std::isfinite(acceptedStatsDynamic[i].mMod))
                    return false;
            }

            return true;
        }

        bool hasServerAcceptedDeadStatsDynamic() const
        {
            if (!hasFiniteAcceptedStatsDynamic())
                return false;

            constexpr float healthDeadEpsilon = 0.001f;
            return acceptedStatsDynamicDead || acceptedStatsDynamic[0].mCurrent <= healthDeadEpsilon;
        }

        bool isClientDeathPacketAllowed() const
        {
            return deathState != 0 && hasServerAcceptedDeadStatsDynamic();
        }

        void restoreAcceptedStatsDynamicPacket()
        {
            if (hasAcceptedStatsDynamicPacket)
            {
                statsDynamicSequence = acceptedStatsDynamicSequence;
                for (int i = 0; i < 3; ++i)
                    creatureStats.mDynamic[i] = acceptedStatsDynamic[i];
                creatureStats.mDead = acceptedStatsDynamicDead;
            }
            else
            {
                statsDynamicSequence = acceptedStatsDynamicSequence;
                for (int i = 0; i < 3; ++i)
                {
                    creatureStats.mDynamic[i].mBase = 0.f;
                    creatureStats.mDynamic[i].mCurrent = 0.f;
                    creatureStats.mDynamic[i].mMod = 0.f;
                }
                creatureStats.mDead = false;
            }

            statsDynamicIndexChanges.clear();
        }

        void clearAcceptedStatsDynamicPacket()
        {
            statsDynamicSequence = 0;
            acceptedStatsDynamicSequence = 0;
            for (int i = 0; i < 3; ++i)
                acceptedStatsDynamic[i] = ESM::StatState<float>();
            acceptedStatsDynamicDead = false;
            hasAcceptedStatsDynamicPacket = false;
            statsDynamicIndexChanges.clear();
        }

        bool acceptStatsDynamicPacket(bool enforceClientAuthority = false)
        {
            if (!hasFiniteDynamicStats())
            {
                restoreAcceptedStatsDynamicPacket();
                return false;
            }

            if (hasAcceptedStatsDynamicPacket
                && !isNewerPlayerStatsDynamicSequence(statsDynamicSequence, acceptedStatsDynamicSequence))
            {
                restoreAcceptedStatsDynamicPacket();
                return false;
            }

            if (enforceClientAuthority && hasAcceptedStatsDynamicPacket)
            {
                constexpr float healthChangeEpsilon = 0.001f;
                const float acceptedHealth = acceptedStatsDynamic[0].mCurrent;
                const float incomingHealth = creatureStats.mDynamic[0].mCurrent;

                if (acceptedStatsDynamicDead && !creatureStats.mDead)
                {
                    restoreAcceptedStatsDynamicPacket();
                    return false;
                }

                if (creatureStats.mDead && incomingHealth > healthChangeEpsilon)
                {
                    restoreAcceptedStatsDynamicPacket();
                    return false;
                }

                if (incomingHealth > acceptedHealth + healthChangeEpsilon)
                {
                    restoreAcceptedStatsDynamicPacket();
                    return false;
                }
            }

            if (enforceClientAuthority && creatureStats.mDead && creatureStats.mDynamic[0].mCurrent > 0.001f)
            {
                restoreAcceptedStatsDynamicPacket();
                return false;
            }

            acceptCurrentStatsDynamicPacket();
            return true;
        }

        void advanceCombatSequence()
        {
            ++combatSequence;
        }

        bool isCombatPacketSequenceAllowed() const
        {
            return !hasAcceptedCombatPacket || isNewerPlayerCombatSequence(combatSequence, acceptedCombatSequence);
        }

        void acceptCurrentCombatPacket()
        {
            acceptedCombatSequence = combatSequence;
            hasAcceptedCombatPacket = true;
        }

        void clearAcceptedCombatPacket()
        {
            combatSequence = 0;
            acceptedCombatSequence = 0;
            attack = Attack();
            cast = Cast();
            hasAcceptedCombatPacket = false;
        }

        bool acceptCombatPacket()
        {
            if (!isCombatPacketSequenceAllowed())
            {
                combatSequence = acceptedCombatSequence;
                return false;
            }

            acceptCurrentCombatPacket();
            return true;
        }

        void clearAcceptedCharacterState()
        {
            clearAcceptedPositionPacket();
            clearAcceptedAnimFlagsPacket();
            clearAcceptedInventoryPacket();
            clearAcceptedSpellbookPacket();
            clearAcceptedEquipmentPacket();
            clearAcceptedStatsDynamicPacket();
            clearAcceptedCombatPacket();

            position = {};
            direction = {};
            movementFlags = 0;
            drawState = 0;
            isJumping = false;
            isFlying = false;
            hasTcl = false;
            inventoryChanges.action = InventoryChanges::SET;
            inventoryChanges.items.clear();
            for (int i = 0; i < equipmentSlotCount; ++i)
                equipmentItems[i] = Item();
            for (int i = 0; i < 3; ++i)
                creatureStats.mDynamic[i] = ESM::StatState<float>();
            creatureStats.mDead = false;
            creatureStats.mDeathAnimationFinished = false;
            deathState = 0;
            killer = Target();
        }

        PacketGuid guid;

        GUIMessageBox guiMessageBox;

        // Track only the indexes of the attributes that have been changed,
        // with the attribute values themselves being stored in creatureStats.mAttributes
        std::vector<uint8_t> attributeIndexChanges;

        // Track only the indexes of the skills that have been changed,
        // with the skill values themselves being stored in npcStats.mSkills
        std::vector<uint8_t> skillIndexChanges;

        // Track only the indexes of the dynamic states that have been changed,
        // with the dynamicStats themselves being stored in creatureStats.mDynamic
        std::vector<uint8_t> statsDynamicIndexChanges;

        // Track only the indexes of the equipment items that have been changed,
        // with the items themselves being stored in equipmentItems
        std::vector<int> equipmentIndexChanges;
        std::uint32_t equipmentSequence = 0;
        std::uint32_t acceptedEquipmentSequence = 0;
        Item acceptedEquipmentItems[equipmentSlotCount] = {};
        bool hasAcceptedEquipmentPacket = false;

        bool exchangeFullInfo = false;

        InventoryChanges inventoryChanges;
        std::uint32_t inventorySequence = 0;
        std::uint32_t acceptedInventorySequence = 0;
        InventoryChanges acceptedInventoryChanges;
        std::vector<Item> acceptedInventoryItems;
        bool hasAcceptedInventoryPacket = false;

        SpellbookChanges spellbookChanges;
        SpellbookChanges acceptedSpellbookChanges;
        std::vector<ESM::Spell> acceptedSpellbookSpells;
        bool hasAcceptedSpellbookPacket = false;
        std::vector<SpellCooldown> cooldownChanges;
        SpellsActiveChanges spellsActiveChanges;
        std::vector<QuickKey> quickKeyChanges;
        std::vector<JournalItem> journalChanges;
        bool journalChangesAreLoad = false;
        FactionChanges factionChanges;
        std::vector<Topic> topicChanges;
        bool topicChangesAreLoad = false;
        std::vector<Book> bookChanges;
        bool bookChangesAreLoad = false;
        std::vector<CellState> cellStateChanges;
        ClientLuaEvent luaEvent;

        std::vector<PacketGuid> alliedPlayers;
        CurrentContainer currentContainer;

        int difficulty = 0;
        int enforcedLogLevel = -1;
        float physicsFramerate = 60.0;
        bool consoleAllowed = false;
        bool bedRestAllowed = true;
        bool wildernessRestAllowed = true;
        bool waitAllowed = true;

        bool ignorePosPacket = false;

        unsigned int movementFlags = 0;
        char drawState = 0;
        bool isJumping = false;
        bool isFlying = false;
        bool hasTcl = false;
        std::uint32_t animFlagsSequence = 0;
        std::uint32_t acceptedAnimFlagsSequence = 0;
        unsigned int acceptedMovementFlags = 0;
        char acceptedDrawState = 0;
        bool acceptedIsJumping = false;
        bool acceptedIsFlying = false;
        bool acceptedHasTcl = false;
        bool hasAcceptedAnimFlagsPacket = false;

        ESM::Position position = {};
        ESM::Position direction = {};
        float movementSampleIntervalSeconds = 1.f / 60.f;
        float movementLatencySeconds = 0.f;
        std::uint32_t positionSequence = 0;
        std::uint32_t acceptedPositionSequence = 0;
        ESM::Position acceptedPosition = {};
        ESM::Position acceptedDirection = {};
        float acceptedMovementSampleIntervalSeconds = 1.f / 60.f;
        float acceptedMovementLatencySeconds = 0.f;
        bool hasAcceptedPositionPacket = false;
        ESM::Position previousCellPosition = {};
        ESM::Position momentum = {};
        ESM::Cell cell;
        // value-initialized: the server asks a client for BaseInfo at connect,
        // long before chargen fills this in, and ESM::NPC::mFlags has no default
        // initializer -- bit 0 of it is ESM::NPC::Female
        ESM::NPC npc{};
        ESM::NpcStats npcStats;
        ESM::Creature creature;
        // value-initialised: ESM::CreatureStats declares plain members such as
        // bool mDead with no initialiser, and acceptStatsDynamicPacket reads mDead
        ESM::CreatureStats creatureStats{};
        std::uint32_t statsDynamicSequence = 0;
        std::uint32_t acceptedStatsDynamicSequence = 0;
        ESM::StatState<float> acceptedStatsDynamic[3] = {};
        bool acceptedStatsDynamicDead = false;
        bool hasAcceptedStatsDynamicPacket = false;
        ESM::Class charClass;
        Item equipmentItems[equipmentSlotCount] = {};
        Attack attack;
        Cast cast;
        std::uint32_t combatSequence = 0;
        std::uint32_t acceptedCombatSequence = 0;
        bool hasAcceptedCombatPacket = false;
        std::string birthsign;
        std::string chatMessage;
        CharGenState charGenState;
        std::map<std::string, std::string> gameSettings;
        std::map<std::string, std::string> vrSettings;

        std::string sound;
        Animation animation;
        char deathState = 0;

        bool resetStats = false;
        float scale = 1;
        bool isWerewolf = false;

        bool displayCreatureName = false;
        std::string creatureRefId;

        bool isChangingRegion = false;
        unsigned int cellChangeReason = CELL_CHANGE_REASON_NORMAL;

        Target killer;

        int jailDays = 0;
        bool ignoreJailTeleportation = false;
        bool ignoreJailSkillIncreases = false;
        std::string jailProgressText;
        std::string jailEndText;

        unsigned int resurrectType = 0;
        unsigned int miscellaneousChangeType = 0;

        ESM::Cell markCell;
        ESM::Position markPosition = {};
        std::string selectedSpellId;
        mwmp::Item selectedEnchantedItem;

        mwmp::Item usedItem;
        bool usingItemMagic = false;
        char itemUseDrawState = 0;
    };
}

#endif //OPENMW_BASEPLAYER_HPP
