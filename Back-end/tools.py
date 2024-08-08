class CustomList(list):
    """
    CustomList class, a subclass of the built-in list class,
    with additional functionality for merge sort.
    """

    def __init__(self, *args, **kwargs):
        """
        Initialize CustomList object.

        Args:
            *args: Variable positional arguments.
            **kwargs: Variable keyword arguments.
        """
        super().__init__(*args, **kwargs)

    def merge_sort(self):
        """
        Perform merge sort on the CustomList.

        Returns:
            CustomList: A new CustomList object containing sorted elements.
        """
        # Check if the list has more than one element
        if len(self) > 1:
            # Find the middle index of the list
            mid = len(self) // 2

            # Recursively apply merge_sort on left and right halves
            left_half = CustomList(self[:mid]).merge_sort()
            right_half = CustomList(self[mid:]).merge_sort()

            # Merge the sorted left and right halves
            i, j, k = 0, 0, 0
            sorted_list = CustomList()

            # Merge the two halves while maintaining the sorted order
            while i < len(left_half) and j < len(right_half):
                if left_half[i] < right_half[j]:
                    sorted_list.append(left_half[i])
                    i += 1
                else:
                    sorted_list.append(right_half[j])
                    j += 1
                k += 1

            # Append remaining elements from left_half, if any
            while i < len(left_half):
                sorted_list.append(left_half[i])
                i += 1
                k += 1

            # Append remaining elements from right_half, if any
            while j < len(right_half):
                sorted_list.append(right_half[j])
                j += 1
                k += 1

            return sorted_list

        # Return a new CustomList with a single element
        return CustomList(self)

class Stack:
    """
    Stack class represents a basic stack data structure.

    Methods:
    - is_empty(): Check if the stack is empty.
    - push(item): Push an item onto the stack.
    - pop(): Pop an item from the top of the stack.
    - peek(): Peek at the top item without removing it.
    - size(): Get the size of the stack.
    """

    def __init__(self):
        # Initialize an empty list to store stack items
        self.items = []

    def is_empty(self):
        """
        Check if the stack is empty.

        Returns:
        bool: True if the stack is empty, False otherwise.
        """
        return len(self.items) == 0

    def push(self, item):
        """
        Push an item onto the stack.

        Args:
        item: The item to be pushed onto the stack.
        """
        self.items.append(item)

    def pop(self):
        """
        Pop an item from the top of the stack.

        Returns:
        item: The item popped from the top of the stack.

        Raises:
        IndexError: If the stack is empty.
        """
        if not self.is_empty():
            return self.items.pop()
        else:
            raise IndexError("pop from an empty stack")

    def peek(self):
        """
        Peek at the top item without removing it.

        Returns:
        item: The item at the top of the stack.

        Raises:
        IndexError: If the stack is empty.
        """
        if not self.is_empty():
            return self.items[-1]
        else:
            raise IndexError("peek from an empty stack")

    def size(self):
        """
        Get the size of the stack.

        Returns:
        int: The number of items in the stack.
        """
        return len(self.items)

class BinarySearch:
    """
    Binary search algorithm for finding an element in a sorted array.
    """
    @staticmethod
    def search(arr, target):
        """
        Perform binary search on a sorted array.

        Args:
            arr (list): Sorted array to search.
            target (int): Element to find in the array.

        Returns:
            int: Index of the target element if found, otherwise -1.
        """
        low, high = 0, len(arr) - 1  # Initialize low and high indices

        # Binary search loop
        while low <= high:
            mid = (low + high) // 2  # Calculate mid index
            mid_element = arr[mid]  # Get the element at mid index

            if mid_element == target:
                return mid  # Target element found, return its index
            elif mid_element < target:
                low = mid + 1  # Adjust low index for the right half
            else:
                high = mid - 1  # Adjust high index for the left half

        return -1  # Target element not found

