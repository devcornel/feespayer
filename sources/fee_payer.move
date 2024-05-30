module fee_payer::fee_payer {
    // Importing necessary modules from the standard library and SUI.
    use sui::sui::SUI;
    use std::vector;
    use sui::transfer;
    use std::string::String;
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::object::{Self, ID, UID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext, sender};
    use sui::table::{Self, Table};
    // Structs definition for the fee payer system.
    // Struct to store information about the school.
    struct School has key, store {
        id: UID,
        name: String,
        balance: Balance<SUI>,
        students: vector<address>,
        payments: Table<ID, FeePayment>,
        invoices: Table<ID, Invoice>,
        school: address,
    }
    // Struct to represent a student.
    struct Student has key, store {
        id: UID,
        student: address,
        school_id: ID,
        balance: Balance<SUI>,
        arrears: u64,
    }
    // Struct to represent a fee payment
    struct FeePayment has key, store {
        id: UID,
        student_id: ID,
        school_id: ID,
        amount: u64,
        invoice: u64,
        paid_date: u64,
    }
    struct Invoice has key, store {
        id: UID,
        student_id: ID,
        school_id: ID,
        payment_for: String,
        amount: u64,
        invoice_date: u64,
    }
    // Error codes used in the fee payer system.
    const ENotSchool: u64 = 0;
    const EInsufficientFunds: u64 = 1;
    const EInsufficientBalance: u64 = 2;
    // Functions for managing the fee payer system.
    // add school
    public fun add_school(
        name: String,
        ctx: &mut TxContext
    ) : School {
        let id = object::new(ctx);
        School {
            id,
            name,
            balance: balance::zero<SUI>(),
            students: vector::empty<address>(),
            invoices: table::new<ID, Invoice>(ctx),
            payments: table::new<ID, FeePayment>(ctx),
            school: tx_context::sender(ctx),
        }
    }
    // add student
    public fun add_student(
        student: address,
        school: &mut School,
        ctx: &mut TxContext
    ) : Student {
        let id = object::new(ctx);
        let new_student = Student {
            id,
            student,
            school_id: object::id(school),
            arrears: 0,
            balance: balance::zero<SUI>(),
        };
        // add student to school
        vector::push_back<address>(&mut school.students, student);
        new_student
    }
    // invoice student
    public fun invoice_student(
        school: &mut School,
        student: &mut Student,
        amount: u64,
        payment_for: String,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let invoice_id = object::new(ctx);
        let invoice = Invoice {
            id: invoice_id,
            student_id: object::id(student),
            school_id: student.school_id,
            amount,
            payment_for,
            invoice_date: clock::timestamp_ms(clock),
        };
        // increase student arrears
        student.arrears = student.arrears + amount;
        // add invoice to school
        table::add<ID, Invoice>(&mut school.invoices, object::uid_to_inner(&invoice.id), invoice);
    }
    // student deposit
    public fun deposit(
        student: &mut Student,
        amount: Coin<SUI>,
    ) {
        let coin = coin::into_balance(amount);
        balance::join(&mut student.balance, coin);
    }
    // student pay fee
    public fun pay_fee(
        school: &mut School,
        student: &mut Student,
        amount: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // check if student has enough balance
       assert!(balance::value(&student.balance) >= amount, EInsufficientFunds);
        // deduct amount from student balance
       let fee_amount = coin::take(&mut student.balance, amount, ctx);
       transfer::public_transfer(fee_amount, school.school);
        // create fee payment
        let payment_id = object::new(ctx);
        let payment = FeePayment {
            id: payment_id,
            student_id: object::id(student),
            school_id: student.school_id,
            amount,
            invoice: 0,
            paid_date: clock::timestamp_ms(clock),
        };
        // add payment to school
        table::add<ID, FeePayment>(&mut school.payments, object::uid_to_inner(&payment.id), payment);
        // decrease student arrears
        student.arrears = student.arrears - amount;
    }
    // school withdraw
    public fun withdraw(
        school: &mut School,
        amount: u64,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == school.school, ENotSchool); // Add access control check
        assert!(balance::value(&school.balance) >= amount, EInsufficientBalance);
        let withdrawn = coin::take(&mut school.balance, amount, ctx);
        transfer::public_transfer(withdrawn, school.school);
    }
}