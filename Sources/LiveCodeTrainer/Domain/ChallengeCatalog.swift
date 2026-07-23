import Foundation

public enum ChallengeCatalog {
    public static let all: [SwiftUIChallenge] = [
        profileCard,
        followButton,
        editableGroceryList,
        validatedSignUpForm,
        asyncUserDirectory,
        typedNavigation,
        expandableCard,
        accessibleStepper
    ]

    public static func challenge(id: ChallengeID) -> SwiftUIChallenge? {
        all.first { $0.id == id }
    }

    public static func challenges(
        difficulty: ChallengeDifficulty? = nil,
        category: ChallengeCategory? = nil
    ) -> [SwiftUIChallenge] {
        all.filter { challenge in
            (difficulty == nil || challenge.difficulty == difficulty)
                && (category == nil || challenge.categories.contains(category!))
        }
    }
}

private extension ChallengeCatalog {
    static let profileCard = SwiftUIChallenge(
        id: "profile-card",
        title: "Profile Card",
        summary: "Recreate a compact profile card with adaptive layout.",
        brief: """
        Build a profile card for Ada Lovelace. It should show a circular avatar
        placeholder, name, role, short biography, and a full-width primary action.
        Keep the hierarchy readable at large Dynamic Type sizes.
        """,
        difficulty: .beginner,
        categories: [.layout, .accessibility],
        estimatedMinutes: 15,
        starterCode: #"""
        import SwiftUI

        struct ProfileCard: View {
            var body: some View {
                // Build the card here.
                Text("Ada Lovelace")
            }
        }
        """#,
        referenceSolution: #"""
        import SwiftUI

        struct ProfileCard: View {
            var body: some View {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 56, height: 56)
                            .foregroundStyle(.purple)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Ada Lovelace")
                                .font(.headline)
                            Text("Computing Pioneer")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text("Mathematician and writer whose notes described the first published algorithm.")
                        .font(.body)

                    Button("View profile") {}
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                }
                .padding(20)
                .frame(maxWidth: 380, alignment: .leading)
                .background(.background, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
                .padding()
            }
        }
        """#,
        requirements: [
            .init(id: "compiles", text: "The view compiles without errors.", verification: .compilation),
            .init(id: "content", text: "Show the name, role, biography, and action title.", verification: .sourceInspection),
            .init(id: "layout", text: "Use a card with leading alignment and consistent spacing.", verification: .snapshot),
            .init(id: "dynamic-type", text: "Content remains readable without fixed text heights.", verification: .manualReview)
        ],
        hints: [
            .init(id: "hierarchy", kind: .direction, title: "Start with hierarchy", content: "Use a vertical container for the card and a horizontal container for avatar plus identity.", scorePenalty: 3),
            .init(id: "shape", kind: .apiReminder, title: "Card background", content: "A shape can be passed directly to background(_:in:).", scorePenalty: 5)
        ],
        followUpPrompts: ["Make the layout switch to vertical at accessibility text sizes."]
    )

    static let followButton = SwiftUIChallenge(
        id: "follow-button-state",
        title: "Follow Button State",
        summary: "Model a small interaction with local state.",
        brief: """
        Implement a follow button. Initially it reads “Follow” and uses a prominent
        style. A tap toggles it to “Following” and changes its icon and style.
        A second tap returns to the initial state.
        """,
        difficulty: .beginner,
        categories: [.stateManagement],
        estimatedMinutes: 10,
        starterCode: #"""
        import SwiftUI

        struct FollowButton: View {
            var body: some View {
                Button("Follow") {
                    // Toggle state.
                }
            }
        }
        """#,
        referenceSolution: #"""
        import SwiftUI

        struct FollowButton: View {
            @State private var isFollowing = false

            var body: some View {
                Button {
                    isFollowing.toggle()
                } label: {
                    Label(
                        isFollowing ? "Following" : "Follow",
                        systemImage: isFollowing ? "checkmark" : "plus"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(isFollowing ? Color.secondary : Color.accentColor)
                .animation(.easeInOut(duration: 0.2), value: isFollowing)
            }
        }
        """#,
        requirements: [
            .init(id: "compiles", text: "The view compiles without errors.", verification: .compilation),
            .init(id: "initial", text: "The initial title is Follow.", verification: .interaction),
            .init(id: "toggle", text: "Each tap toggles between Follow and Following.", verification: .interaction),
            .init(id: "private-state", text: "Interaction state is owned privately by the view.", verification: .sourceInspection)
        ],
        hints: [
            .init(id: "state", kind: .apiReminder, title: "Local state", content: "Store a Boolean with @State and change it inside the button action.", scorePenalty: 4),
            .init(id: "toggle", kind: .codeFragment, title: "Toggle a Boolean", content: "isFollowing.toggle()", scorePenalty: 8)
        ]
    )

    static let editableGroceryList = SwiftUIChallenge(
        id: "editable-grocery-list",
        title: "Editable Grocery List",
        summary: "Build an identifiable list with insertion and deletion.",
        brief: """
        Display grocery items in a List. Users can enter a non-empty item name,
        add it to the list, mark rows complete, and delete rows with standard
        swipe-to-delete behavior.
        """,
        difficulty: .intermediate,
        categories: [.lists, .stateManagement, .forms],
        estimatedMinutes: 25,
        starterCode: #"""
        import SwiftUI

        struct GroceryItem: Identifiable {
            let id = UUID()
            var name: String
            var isComplete = false
        }

        struct GroceryListView: View {
            @State private var items: [GroceryItem] = []
            @State private var newItemName = ""

            var body: some View {
                Text("Implement the grocery list")
            }
        }
        """#,
        referenceSolution: #"""
        import SwiftUI

        struct GroceryItem: Identifiable {
            let id = UUID()
            var name: String
            var isComplete = false
        }

        struct GroceryListView: View {
            @State private var items: [GroceryItem] = []
            @State private var newItemName = ""

            var body: some View {
                VStack {
                    HStack {
                        TextField("New item", text: $newItemName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(addItem)
                        Button("Add", action: addItem)
                            .disabled(trimmedName.isEmpty)
                    }
                    .padding()

                    List {
                        ForEach($items) { $item in
                            Button {
                                item.isComplete.toggle()
                            } label: {
                                Label(
                                    item.name,
                                    systemImage: item.isComplete ? "checkmark.circle.fill" : "circle"
                                )
                                .strikethrough(item.isComplete)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { items.remove(atOffsets: $0) }
                    }
                }
            }

            private var trimmedName: String {
                newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            private func addItem() {
                guard !trimmedName.isEmpty else { return }
                items.append(GroceryItem(name: trimmedName))
                newItemName = ""
            }
        }
        """#,
        requirements: [
            .init(id: "compiles", text: "The view compiles without errors.", verification: .compilation),
            .init(id: "add", text: "A trimmed, non-empty name creates a new row and clears the field.", verification: .interaction),
            .init(id: "complete", text: "Tapping a row visibly toggles its completion state.", verification: .interaction),
            .init(id: "delete", text: "Rows support standard List deletion.", verification: .interaction),
            .init(id: "identity", text: "Rows use stable item identity.", verification: .sourceInspection)
        ],
        hints: [
            .init(id: "bindings", kind: .direction, title: "Mutating rows", content: "Iterate over $items to receive a binding for each mutable item.", scorePenalty: 5),
            .init(id: "delete", kind: .apiReminder, title: "Delete modifier", content: "Attach onDelete(perform:) to ForEach and remove the supplied IndexSet.", scorePenalty: 7)
        ],
        followUpPrompts: ["Add an empty state without replacing the List.", "Persist items between launches."]
    )

    static let validatedSignUpForm = SwiftUIChallenge(
        id: "validated-sign-up-form",
        title: "Validated Sign-up Form",
        summary: "Create derived validation state and clear user feedback.",
        brief: """
        Build an email/password form. Email must contain “@”; the password must
        contain at least eight characters. Disable submission until both are valid,
        and show validation messages only after the user attempts to submit.
        """,
        difficulty: .intermediate,
        categories: [.forms, .stateManagement, .accessibility],
        estimatedMinutes: 20,
        starterCode: #"""
        import SwiftUI

        struct SignUpForm: View {
            @State private var email = ""
            @State private var password = ""

            var body: some View {
                Form {
                    // Add fields, validation, and submit action.
                }
            }
        }
        """#,
        referenceSolution: #"""
        import SwiftUI

        struct SignUpForm: View {
            @State private var email = ""
            @State private var password = ""
            @State private var attemptedSubmit = false

            private var emailIsValid: Bool { email.contains("@") }
            private var passwordIsValid: Bool { password.count >= 8 }
            private var formIsValid: Bool { emailIsValid && passwordIsValid }

            var body: some View {
                Form {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)

                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)

                    if attemptedSubmit && !emailIsValid {
                        Text("Enter a valid email address.")
                            .foregroundStyle(.red)
                            .accessibilityLabel("Email error: Enter a valid email address.")
                    }
                    if attemptedSubmit && !passwordIsValid {
                        Text("Password must be at least 8 characters.")
                            .foregroundStyle(.red)
                    }

                    Button("Create account") {
                        attemptedSubmit = true
                        guard formIsValid else { return }
                    }
                    .disabled(!formIsValid)
                }
                .onSubmit {
                    attemptedSubmit = true
                }
            }
        }
        """#,
        requirements: [
            .init(id: "compiles", text: "The view compiles without errors.", verification: .compilation),
            .init(id: "fields", text: "Use appropriate email and secure text fields.", verification: .sourceInspection),
            .init(id: "disabled", text: "Submission is disabled while input is invalid.", verification: .interaction),
            .init(id: "feedback", text: "An attempted invalid submission produces specific feedback.", verification: .interaction),
            .init(id: "derived", text: "Validity is derived rather than duplicated as mutable state.", verification: .manualReview)
        ],
        hints: [
            .init(id: "derived", kind: .direction, title: "Derive validity", content: "Use computed properties based on the two input strings.", scorePenalty: 4),
            .init(id: "secure", kind: .apiReminder, title: "Password input", content: "SecureField masks entered text and accepts a String binding.", scorePenalty: 4)
        ]
    )

    static let asyncUserDirectory = SwiftUIChallenge(
        id: "async-user-directory",
        title: "Async User Directory",
        summary: "Represent loading, success, empty, and failure states.",
        brief: """
        Load users from the supplied async service when the view appears. Show a
        progress indicator while loading, a retryable error state on failure, an
        empty state for no users, and a list on success. Avoid starting duplicate
        loads during ordinary body updates.
        """,
        difficulty: .advanced,
        categories: [.concurrency, .lists, .stateManagement],
        estimatedMinutes: 35,
        starterCode: #"""
        import SwiftUI

        struct User: Identifiable, Sendable {
            let id: Int
            let name: String
        }

        protocol UserLoading: Sendable {
            func loadUsers() async throws -> [User]
        }

        struct UserDirectoryView: View {
            let service: any UserLoading

            var body: some View {
                Text("Load users")
            }
        }
        """#,
        referenceSolution: #"""
        import SwiftUI

        struct User: Identifiable, Sendable {
            let id: Int
            let name: String
        }

        protocol UserLoading: Sendable {
            func loadUsers() async throws -> [User]
        }

        struct UserDirectoryView: View {
            enum LoadState {
                case loading
                case loaded([User])
                case failed(String)
            }

            let service: any UserLoading
            @State private var state: LoadState = .loading

            var body: some View {
                Group {
                    switch state {
                    case .loading:
                        ProgressView("Loading users")
                    case .loaded(let users) where users.isEmpty:
                        ContentUnavailableView("No users", systemImage: "person.2")
                    case .loaded(let users):
                        List(users) { user in
                            Text(user.name)
                        }
                    case .failed(let message):
                        ContentUnavailableView {
                            Label("Couldn’t load users", systemImage: "wifi.exclamationmark")
                        } description: {
                            Text(message)
                        } actions: {
                            Button("Retry") {
                                Task { await load() }
                            }
                        }
                    }
                }
                .task { await load() }
            }

            @MainActor
            private func load() async {
                state = .loading
                do {
                    state = .loaded(try await service.loadUsers())
                } catch is CancellationError {
                    return
                } catch {
                    state = .failed(error.localizedDescription)
                }
            }
        }
        """#,
        requirements: [
            .init(id: "compiles", text: "The view compiles under Swift 6 concurrency checks.", verification: .compilation),
            .init(id: "states", text: "Loading, populated, empty, and failure states are distinct.", verification: .interaction),
            .init(id: "task", text: "Initial work uses a lifecycle-bound task.", verification: .sourceInspection),
            .init(id: "retry", text: "The error state exposes a retry action.", verification: .interaction),
            .init(id: "main-actor", text: "UI state mutations are main-actor safe.", verification: .sourceInspection)
        ],
        hints: [
            .init(id: "enum", kind: .direction, title: "One source of truth", content: "An enum with associated values prevents impossible combinations of loading flags and data.", scorePenalty: 5),
            .init(id: "task", kind: .apiReminder, title: "View lifecycle", content: "The task modifier starts async work and cancels it when the view disappears.", scorePenalty: 6)
        ],
        followUpPrompts: ["Add pull-to-refresh without showing the full-screen loading state.", "Explain how cancellation is handled."]
    )

    static let typedNavigation = SwiftUIChallenge(
        id: "typed-navigation",
        title: "Typed Navigation",
        summary: "Create value-driven navigation with programmatic reset.",
        brief: """
        Build a two-step flow: a list of projects opens project details, and details
        can open a settings screen. Use value-based NavigationStack destinations.
        Settings must include a button that returns directly to the root.
        """,
        difficulty: .advanced,
        categories: [.navigation, .stateManagement],
        estimatedMinutes: 30,
        starterCode: #"""
        import SwiftUI

        struct Project: Identifiable, Hashable {
            let id: Int
            let name: String
        }

        struct ProjectFlow: View {
            let projects = [
                Project(id: 1, name: "Apollo"),
                Project(id: 2, name: "Gemini")
            ]

            var body: some View {
                Text("Build the navigation flow")
            }
        }
        """#,
        referenceSolution: #"""
        import SwiftUI

        struct Project: Identifiable, Hashable {
            let id: Int
            let name: String
        }

        struct ProjectFlow: View {
            enum Route: Hashable {
                case project(Project)
                case settings(Project)
            }

            let projects = [
                Project(id: 1, name: "Apollo"),
                Project(id: 2, name: "Gemini")
            ]
            @State private var path: [Route] = []

            var body: some View {
                NavigationStack(path: $path) {
                    List(projects) { project in
                        NavigationLink(project.name, value: Route.project(project))
                    }
                    .navigationTitle("Projects")
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .project(let project):
                            VStack {
                                Text(project.name).font(.title)
                                NavigationLink("Settings", value: Route.settings(project))
                            }
                            .navigationTitle("Details")
                        case .settings(let project):
                            VStack(spacing: 16) {
                                Text("\(project.name) Settings")
                                Button("Back to projects") { path.removeAll() }
                            }
                            .navigationTitle("Settings")
                        }
                    }
                }
            }
        }
        """#,
        requirements: [
            .init(id: "compiles", text: "The view compiles without errors.", verification: .compilation),
            .init(id: "value-links", text: "Navigation uses Hashable values instead of destination closures.", verification: .sourceInspection),
            .init(id: "details", text: "Selecting a project opens its matching detail screen.", verification: .interaction),
            .init(id: "settings", text: "Details can navigate to settings for the same project.", verification: .interaction),
            .init(id: "root", text: "Settings can programmatically return to the project list.", verification: .interaction)
        ],
        hints: [
            .init(id: "route", kind: .direction, title: "Model routes", content: "Create a Hashable route enum and store an array of routes as the stack path.", scorePenalty: 6),
            .init(id: "reset", kind: .codeFragment, title: "Reset the stack", content: "path.removeAll()", scorePenalty: 8)
        ]
    )

    static let expandableCard = SwiftUIChallenge(
        id: "expandable-card-animation",
        title: "Expandable Card",
        summary: "Animate a state-driven disclosure without breaking accessibility.",
        brief: """
        Create a summary card with title and chevron. Tapping it reveals descriptive
        text and rotates the chevron. Animate only changes driven by the expanded
        state and expose the correct expanded/collapsed accessibility value.
        """,
        difficulty: .intermediate,
        categories: [.animation, .stateManagement, .accessibility],
        estimatedMinutes: 20,
        starterCode: #"""
        import SwiftUI

        struct ExpandableCard: View {
            @State private var isExpanded = false

            var body: some View {
                Text("SwiftUI")
            }
        }
        """#,
        referenceSolution: #"""
        import SwiftUI

        struct ExpandableCard: View {
            @State private var isExpanded = false

            var body: some View {
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        isExpanded.toggle()
                    } label: {
                        HStack {
                            Text("SwiftUI").font(.headline)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")

                    if isExpanded {
                        Text("Build user interfaces across Apple platforms with declarative Swift.")
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding()
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
                .animation(.snappy, value: isExpanded)
            }
        }
        """#,
        requirements: [
            .init(id: "compiles", text: "The view compiles without errors.", verification: .compilation),
            .init(id: "toggle", text: "Tapping the header reveals and hides the description.", verification: .interaction),
            .init(id: "chevron", text: "The chevron visually reflects expansion.", verification: .snapshot),
            .init(id: "scoped-animation", text: "Animation is scoped to expanded state changes.", verification: .sourceInspection),
            .init(id: "a11y", text: "Assistive technology can identify expanded versus collapsed state.", verification: .sourceInspection)
        ],
        hints: [
            .init(id: "value-animation", kind: .apiReminder, title: "Scoped animation", content: "Use animation(_:value:) with the Boolean state.", scorePenalty: 5),
            .init(id: "transition", kind: .direction, title: "Insertion and removal", content: "Apply a transition to the conditional description view.", scorePenalty: 5)
        ]
    )

    static let accessibleStepper = SwiftUIChallenge(
        id: "accessible-quantity-control",
        title: "Accessible Quantity Control",
        summary: "Build a custom control with bounds and adjustable actions.",
        brief: """
        Create a quantity selector from 1 through 10 using minus and plus buttons.
        Buttons must disable at their respective bounds. VoiceOver should treat the
        control as a single adjustable element and announce the current quantity.
        """,
        difficulty: .intermediate,
        categories: [.stateManagement, .accessibility],
        estimatedMinutes: 20,
        starterCode: #"""
        import SwiftUI

        struct QuantityControl: View {
            @State private var quantity = 1

            var body: some View {
                Text("Quantity: \(quantity)")
            }
        }
        """#,
        referenceSolution: #"""
        import SwiftUI

        struct QuantityControl: View {
            @State private var quantity = 1

            var body: some View {
                HStack(spacing: 20) {
                    Button {
                        decrement()
                    } label: {
                        Image(systemName: "minus")
                    }
                    .disabled(quantity == 1)

                    Text(quantity, format: .number)
                        .monospacedDigit()
                        .frame(minWidth: 32)

                    Button {
                        increment()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(quantity == 10)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Quantity")
                .accessibilityValue("\(quantity)")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: increment()
                    case .decrement: decrement()
                    @unknown default: break
                    }
                }
            }

            private func increment() {
                quantity = min(quantity + 1, 10)
            }

            private func decrement() {
                quantity = max(quantity - 1, 1)
            }
        }
        """#,
        requirements: [
            .init(id: "compiles", text: "The view compiles without errors.", verification: .compilation),
            .init(id: "bounds", text: "Quantity never leaves the closed range 1...10.", verification: .interaction),
            .init(id: "disabled", text: "Minus and plus buttons disable at lower and upper bounds.", verification: .interaction),
            .init(id: "a11y-value", text: "The grouped control announces its label and current value.", verification: .sourceInspection),
            .init(id: "adjustable", text: "VoiceOver increment and decrement actions update the value.", verification: .interaction)
        ],
        hints: [
            .init(id: "group", kind: .direction, title: "One accessible control", content: "Combine children into one accessibility element and supply a label and value.", scorePenalty: 5),
            .init(id: "adjust", kind: .apiReminder, title: "Adjustable action", content: "accessibilityAdjustableAction receives increment and decrement directions.", scorePenalty: 7)
        ],
        followUpPrompts: ["Make the range configurable without allowing an invalid initial value."]
    )
}
