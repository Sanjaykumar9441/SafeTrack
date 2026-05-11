import { render, screen } from '@testing-library/react';
import DashboardHome from './DashboardHome';

// Mock firebase
jest.mock('../../firebase', () => ({
    db: {},
}));

// Mock toast
jest.mock('react-hot-toast', () => ({
    error: jest.fn(),
}));

// Mock firestore
jest.mock('firebase/firestore', () => ({

    collection: jest.fn(() => ({})),

    query: jest.fn(() => ({})),

    where: jest.fn(() => ({})),

    orderBy: jest.fn(() => ({})),

    limit: jest.fn(() => ({})),

    onSnapshot: jest.fn((ref, successCallback) => {

        successCallback({
            size: 1,

            docs: [
                {
                    id: '1',

                    data: () => ({
                        isActive: true,
                        severity: 'LOW',
                        message: 'Test Alert',
                        busNumber: 'BUS-101',
                        alertType: 'TEST',
                    }),
                },
            ],
        });

        // IMPORTANT
        return () => { };
    }),

}));

describe('DashboardHome Component', () => {

    test('renders dashboard component', () => {

        render(<DashboardHome />);

        expect(
            screen.getByText(/SafeTrack Admin Panel/i)
        ).toBeInTheDocument();

    });

});