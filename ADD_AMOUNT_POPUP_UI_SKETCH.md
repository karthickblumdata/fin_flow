# Add Amount Popup - UI Sketch

## Overview
A modal dialog popup that appears when clicking the "Add Amount" button in the "All Account Reports" screen. The popup allows users to either add an amount or withdraw an amount from an account.

---

## Layout Structure

```
┌─────────────────────────────────────────────────────────────┐
│                    DIALOG CONTAINER                          │
│  (Rounded corners: 20px, Max width: 600px on desktop)     │
│  (Full width on mobile, Max height: 90% of screen)          │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  HEADER SECTION                                       │ │
│  │  ┌──────┐  Add Amount / Withdraw                      │ │
│  │  │  ➕  │  (Green circle icon, 40x40px)                │ │
│  │  └──────┘  (Text: AppTheme.headingMedium)             │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  MODE TOGGLE (Segmented Control)                       │ │
│  │  ┌──────────────────┐  ┌──────────────────┐          │ │
│  │  │ ➕ Add Amount     │  │ ➖ Withdraw      │          │ │
│  │  │ (Active: Green)  │  │ (Inactive: Grey) │          │ │
│  │  └──────────────────┘  └──────────────────┘          │ │
│  │  (Light green background when active)                  │ │
│  │  (Light red background when withdraw active)           │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  ACCOUNT SELECTION                                     │ │
│  │  Account Selection                                     │ │
│  │  ┌──────────────────────────────────────┐             │ │
│  │  │ 🏛️  Select an account      ▼          │             │ │
│  │  └──────────────────────────────────────┘             │ │
│  │  (Required field, dropdown with account list)          │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  AMOUNT FIELD                                           │ │
│  │  ┌────┐                                                 │ │
│  │  │ ₹  │  Amount                                         │ │
│  │  └────┘  [________________]                            │ │
│  │          (Input with rupee icon)                        │ │
│  │          (Validation: Required, > 0, decimal allowed)  │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  REMARK FIELD (Optional)                                │ │
│  │  ┌────┐                                                 │ │
│  │  │ 📝 │  Remark                                         │ │
│  │  └────┘  ┌──────────────────────────────────────┐      │ │
│  │          │                                      │      │ │
│  │          │  Enter remark (optional)            │      │ │
│  │          │                                      │      │ │
│  │          └──────────────────────────────────────┘      │ │
│  │  (Multi-line: 3 lines, Optional field)                 │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  ACTION BUTTONS                                         │ │
│  │  ┌──────────────┐    ┌──────────────────────────┐      │ │
│  │  │   Cancel      │    │   Add Amount / Withdraw │      │ │
│  │  └──────────────┘    └──────────────────────────┘      │ │
│  │  (Outlined, Purple text)  (Green/Red, 2x width)         │ │
│  │  (White background)      (Loading spinner when submit)  │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Visual Design Details

### Colors & Styling
- **Dialog Background**: White
- **Border Radius**: 20px
- **Padding**: 20px (mobile) / 24px (desktop)
- **Header Icon**: Green circle (`AppTheme.secondaryColor`) with white plus icon
- **Mode Toggle Active**: Light green background (`AppTheme.secondaryColor` with 0.1 alpha) for Add Amount
- **Mode Toggle Active**: Light red background (`AppTheme.errorColor` with 0.1 alpha) for Withdraw
- **Primary Button**: Green (`AppTheme.secondaryColor`) for Add Amount, Red (`AppTheme.errorColor`) for Withdraw
- **Cancel Button**: Outlined with gray border, purple text

### Typography
- **Header**: `AppTheme.headingMedium` (40x40px icon, bold text)
- **Labels**: `AppTheme.labelMedium`
- **Body Text**: `AppTheme.bodyMedium`
- **Button Text**: 16px, FontWeight.w600

### Spacing
- Between sections: 20-32px
- Internal padding: 12px (mode toggle), 16px (form fields)
- Button padding: 16px vertical

### Icons
- **Header**: Green circle with white `add` icon (40x40px)
- **Mode Toggle**: 
  - Add Amount: `add_circle_outline` (green when active)
  - Withdraw: `remove_circle_outline` (red when active)
- **Amount**: `currency_rupee_outlined` (prefix)
- **Account**: `account_balance_outlined` (🏛️)
- **Remark**: `note_outlined` (📝)

---

## Field Details

### 1. Mode Toggle (Add Amount / Withdraw)
- **Type**: Segmented control with two options
- **Default**: "Add Amount" (active)
- **Options**: 
  - "Add Amount" (left side, green when active)
  - "Withdraw" (right side, red when active)
- **Display**: Icon + Text in each segment
- **Container**: Gray background box with border, rounded corners
- **Behavior**: 
  - Active mode has light background color (green for Add, red for Withdraw)
  - Changes button text and color dynamically

### 2. Account Selection
- **Type**: Dropdown (always visible)
- **Label**: "Account Selection"
- **Icon**: Bank building icon (🏛️)
- **Placeholder**: "Select an account"
- **Validation**: Required field
- **Options**: Shows all available accounts from `_accountList`

### 3. Amount Field
- **Type**: Text input (number)
- **Format**: Decimal (allows decimal values)
- **Prefix Icon**: Rupee symbol (₹)
- **Validation**: 
  - Required
  - Must be > 0
  - Must be valid number

### 4. Remark Field
- **Type**: Multi-line text (3 lines)
- **Optional**: Yes
- **Placeholder**: "Enter remark (optional)"

---

## Button Behavior

### Cancel Button
- **Style**: Outlined (gray border, white background)
- **Text Color**: Purple (`AppTheme.primaryColor`)
- **Action**: 
  - Closes dialog
  - Clears all form fields
  - Resets state

### Add Amount / Withdraw Button
- **Style**: Filled button (2x width of Cancel)
- **Color**: 
  - Green (`AppTheme.secondaryColor`) when "Add Amount" mode
  - Red (`AppTheme.errorColor`) when "Withdraw" mode
- **Text**: 
  - "Add Amount" when Add Amount mode is active
  - "Withdraw" when Withdraw mode is active
- **States**:
  - **Normal**: Button text based on mode
  - **Loading**: White spinner (20x20px)
  - **Disabled**: When submitting
- **Action**:
  - Validates all fields
  - Shows error if account not selected
  - Calls appropriate API method based on mode:
    - `WalletService.addAmountToAccount()` for Add Amount
    - `WalletService.withdrawFromAccount()` for Withdraw
  - Shows success/error snackbar
  - Closes dialog on success
  - Refreshes dashboard data

---

## Responsive Behavior

### Mobile (< 600px)
- Full width dialog
- Padding: 20px
- Stacked layout

### Desktop/Tablet (≥ 600px)
- Max width: 600px
- Centered on screen
- Padding: 24px

---

## User Flow

1. User clicks "Add Amount" button in All Account Reports
2. Dialog opens with form (default: "Add Amount" mode active)
3. User can toggle between "Add Amount" and "Withdraw" modes
4. User selects an account from dropdown (required)
5. User enters amount (required)
6. User optionally adds remark
7. User clicks "Add Amount" or "Withdraw" button (based on active mode)
8. Form validates
9. If valid, shows loading spinner
10. On success: Shows success message, closes dialog, refreshes data
11. On error: Shows error message, keeps dialog open

---

## Error States

- **Amount empty**: "Please enter an amount"
- **Amount invalid**: "Please enter a valid amount"
- **Account not selected**: "Please select an account"
- **API Error**: Shows error snackbar with message

---

## Success State

- Green success snackbar: "Amount added successfully" or "Amount withdrawn successfully"
- Dialog closes automatically
- Dashboard data refreshes
- Form fields cleared
